use std::collections::{BTreeMap, HashMap};
use std::ffi::CString;
use std::fs::File;
use std::io::{BufWriter, Write};
use std::os::raw::{c_char, c_int, c_long, c_uint, c_ulong, c_void};
use std::ptr;

const WIDTH: usize = 10;
const HEIGHT: usize = 20;
const BPG: usize = WIDTH * HEIGHT;
const FT_LOAD_RENDER: c_int = 4;

const FONT_PATHS: &[(&str, c_uint)] = &[
    ("/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Medium.ttf", 15),
    ("/usr/share/fonts/TTF/NotoSansMNerdFontMono-Medium.ttf", 15),
    ("/usr/share/fonts/TTF/DejaVuSansMono.ttf", 14),
    ("/usr/share/fonts/IosevkaNerdFont/IosevkaNerdFontMono-Medium.ttf", 16),
    ("/usr/share/fonts/noto/NotoSansMath-Regular.ttf", 14),
    ("/usr/share/fonts/noto/NotoSansSymbols-Medium.ttf", 14),
    ("/usr/share/fonts/noto/NotoSansSymbols2-Regular.ttf", 14),
];

#[link(name = "freetype")]
extern "C" {
    fn FT_Init_FreeType(alibrary: *mut *mut c_void) -> c_int;
    fn FT_Done_FreeType(library: *mut c_void) -> c_int;
    fn FT_New_Face(
        library: *mut c_void,
        filepathname: *const c_char,
        face_index: c_long,
        aface: *mut *mut u8,
    ) -> c_int;
    fn FT_Done_Face(face: *mut u8) -> c_int;
    fn FT_Set_Pixel_Sizes(face: *mut u8, pixel_width: c_uint, pixel_height: c_uint) -> c_int;
    fn FT_Load_Char(face: *mut u8, char_code: c_ulong, load_flags: c_int) -> c_int;
    fn FT_Get_First_Char(face: *mut u8, agindex: *mut c_uint) -> c_ulong;
    fn FT_Get_Next_Char(face: *mut u8, char_code: c_ulong, agindex: *mut c_uint) -> c_ulong;
}

unsafe fn render_char(face: *mut u8, cp: u32) -> Option<[u8; BPG]> {
    if FT_Load_Char(face, cp as c_ulong, FT_LOAD_RENDER) != 0 {
        return None;
    }
    let size_ptr = *(face.add(160) as *const *const u8);
    let ascender_26_6 = *(size_ptr.add(48) as *const c_long);
    let ascender = ((ascender_26_6 + 32) >> 6) as i32;

    let glyph_ptr = *(face.add(152) as *const *const u8);
    let bm_rows = *(glyph_ptr.add(152) as *const c_uint) as i32;
    let bm_width = *(glyph_ptr.add(156) as *const c_uint) as i32;
    let bm_pitch = *(glyph_ptr.add(160) as *const c_int);
    let bm_buf = *(glyph_ptr.add(168) as *const *const u8);
    let bm_left = *(glyph_ptr.add(192) as *const c_int);
    let bm_top = *(glyph_ptr.add(196) as *const c_int);

    let mut raw = [0u8; BPG];
    if !bm_buf.is_null() && bm_rows > 0 && bm_width > 0 {
        let y_off = ascender - bm_top;
        let x_off = bm_left;
        for row in 0..bm_rows {
            let dst_y = y_off + row;
            if dst_y < 0 || dst_y >= HEIGHT as i32 {
                continue;
            }
            for col in 0..bm_width {
                let dst_x = x_off + col;
                if dst_x < 0 || dst_x >= WIDTH as i32 {
                    continue;
                }
                let val = *bm_buf.offset((row * bm_pitch + col) as isize);
                raw[dst_y as usize * WIDTH + dst_x as usize] = val;
            }
        }
    }

    if (0x2500..=0x257F).contains(&cp) {
        for y in 0..HEIGHT {
            if raw[y * WIDTH + 8] > 128 {
                raw[y * WIDTH + 9] = raw[y * WIDTH + 8];
            }
        }
    }

    Some(raw)
}

fn main() {
    unsafe {
        let mut lib: *mut c_void = ptr::null_mut();
        assert_eq!(FT_Init_FreeType(&mut lib), 0, "Failed to init FreeType");

        let mut faces: Vec<*mut u8> = Vec::new();
        for &(path, sz) in FONT_PATHS {
            let cpath = CString::new(path).unwrap();
            let mut face: *mut u8 = ptr::null_mut();
            if FT_New_Face(lib, cpath.as_ptr(), 0, &mut face) == 0 {
                FT_Set_Pixel_Sizes(face, 0, sz);
                faces.push(face);
            } else {
                eprintln!("Skipping {}", path);
            }
        }
        assert!(!faces.is_empty(), "No fonts loaded");

        let mut all_codepoints: BTreeMap<u32, *mut u8> = BTreeMap::new();
        for &face in faces.iter().rev() {
            let mut gindex: c_uint = 0;
            let mut cp = FT_Get_First_Char(face, &mut gindex);
            while gindex != 0 {
                let cp32 = cp as u32;
                if cp32 <= 0x10ffff && !(0xd800..=0xdfff).contains(&cp32) {
                    all_codepoints.insert(cp32, face);
                }
                cp = FT_Get_Next_Char(face, cp, &mut gindex);
            }
        }

        let mut unique_glyphs: HashMap<[u8; BPG], u32> = HashMap::new();
        let mut glyph_data: Vec<u8> = Vec::new();
        let mut mapping: BTreeMap<u32, u32> = BTreeMap::new();

        let blank = [0u8; BPG];
        unique_glyphs.insert(blank, 0);
        glyph_data.extend_from_slice(&blank);

        let q_bytes = render_char(faces[0], b'?' as u32).unwrap_or(blank);
        unique_glyphs.insert(q_bytes, 1);
        glyph_data.extend_from_slice(&q_bytes);

        for (&cp, &face) in &all_codepoints {
            if let Some(raw) = render_char(face, cp) {
                let idx = if let Some(&existing) = unique_glyphs.get(&raw) {
                    existing
                } else {
                    let next_idx = unique_glyphs.len() as u32;
                    unique_glyphs.insert(raw, next_idx);
                    glyph_data.extend_from_slice(&raw);
                    next_idx
                };
                mapping.insert(cp, idx);
            }
        }

        mapping.insert(32, 0);
        mapping.insert(63, 1);

        let glyph_count = unique_glyphs.len() as u32;
        let map_count = mapping.len() as u32;
        let out_path = "assets/nerd_font.bin";

        println!("Generating {}:", out_path);
        println!("  Unique glyphs: {}", glyph_count);
        println!("  Unicode mappings: {}", map_count);

        let mut f = BufWriter::new(File::create(out_path).expect("Failed to create output file"));
        f.write_all(&glyph_count.to_le_bytes()).unwrap();
        f.write_all(&map_count.to_le_bytes()).unwrap();
        f.write_all(&glyph_data).unwrap();
        for (&cp, &idx) in &mapping {
            f.write_all(&cp.to_le_bytes()).unwrap();
            f.write_all(&idx.to_le_bytes()).unwrap();
        }
        f.flush().unwrap();

        for face in faces {
            FT_Done_Face(face);
        }
        FT_Done_FreeType(lib);
    }
}
