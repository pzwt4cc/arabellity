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

const LIGATURES: &[(&str, usize, u32)] = &[
    ("equal_equal_equal.liga", 3, 0xEE00),
    ("exclam_equal_equal.liga", 3, 0xEE03),
    ("equal_equal.liga", 2, 0xEE10),
    ("equal_greater.liga", 2, 0xEE12),
    ("hyphen_greater.liga", 2, 0xEE14),
    ("exclam_equal.liga", 2, 0xEE16),
    ("less_equal.liga", 2, 0xEE18),
    ("greater_equal.liga", 2, 0xEE1A),
    ("colon_equal.liga", 2, 0xEE1C),
    ("colon_colon.liga", 2, 0xEE1E),
    ("less_hyphen.liga", 2, 0xEE20),
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
    fn FT_Get_Name_Index(face: *mut u8, glyph_name: *const c_char) -> c_uint;
    fn FT_Load_Glyph(face: *mut u8, glyph_index: c_uint, load_flags: c_int) -> c_int;
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
        let mut x_off = bm_left;

        if bm_width <= WIDTH as i32 {
            if x_off < 0 {
                x_off = 0;
            }
            if x_off + bm_width > WIDTH as i32 {
                x_off = (WIDTH as i32 - bm_width).max(0);
            }
        }

        let scale = if bm_width > WIDTH as i32 || bm_rows > HEIGHT as i32 {
            (bm_width as f32 / WIDTH as f32).max(bm_rows as f32 / HEIGHT as f32)
        } else {
            1.0
        };

        if scale > 1.0 {
            let target_w = ((bm_width as f32 / scale).round() as i32).clamp(1, WIDTH as i32);
            let target_h = ((bm_rows as f32 / scale).round() as i32).clamp(1, HEIGHT as i32);
            let dst_x0 = (WIDTH as i32 - target_w) / 2;
            let dst_y0 = (HEIGHT as i32 - target_h) / 2;

            for r in 0..target_h {
                let src_r = ((r as f32 * scale).round() as i32).clamp(0, bm_rows - 1);
                for c in 0..target_w {
                    let src_c = ((c as f32 * scale).round() as i32).clamp(0, bm_width - 1);
                    let val = *bm_buf.offset((src_r * bm_pitch + src_c) as isize);
                    raw[(dst_y0 + r) as usize * WIDTH + (dst_x0 + c) as usize] = val;
                }
            }
        } else {
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

unsafe fn render_ligature_slices(face: *mut u8, name: &str, cells: usize) -> Option<Vec<[u8; BPG]>> {
    let cname = CString::new(name).ok()?;
    let gid = FT_Get_Name_Index(face, cname.as_ptr());
    if gid == 0 {
        return None;
    }
    if FT_Load_Glyph(face, gid, FT_LOAD_RENDER) != 0 {
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

    let total_width = cells * WIDTH;
    let mut canvas = vec![0u8; total_width * HEIGHT];

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
                if dst_x < 0 || dst_x >= total_width as i32 {
                    continue;
                }
                let val = *bm_buf.offset((row * bm_pitch + col) as isize);
                canvas[dst_y as usize * total_width + dst_x as usize] = val;
            }
        }
    }

    let mut slices = Vec::with_capacity(cells);
    for c in 0..cells {
        let mut slice = [0u8; BPG];
        for row in 0..HEIGHT {
            for col in 0..WIDTH {
                slice[row * WIDTH + col] = canvas[row * total_width + (c * WIDTH + col)];
            }
        }
        slices.push(slice);
    }

    Some(slices)
}

fn main() {
    let mut library: *mut c_void = ptr::null_mut();
    unsafe {
        if FT_Init_FreeType(&mut library) != 0 {
            eprintln!("Failed to init FreeType");
            return;
        }

        let mut unique_glyphs: HashMap<[u8; BPG], u32> = HashMap::new();
        let mut glyph_data: Vec<u8> = Vec::new();
        let mut mapping: BTreeMap<u32, u32> = BTreeMap::new();

        let space_bitmap = [0u8; BPG];
        unique_glyphs.insert(space_bitmap, 0);
        glyph_data.extend_from_slice(&space_bitmap);
        mapping.insert(32, 0);

        for &(font_path, font_size) in FONT_PATHS {
            let c_path = match CString::new(font_path) {
                Ok(p) => p,
                Err(_) => continue,
            };
            let mut face: *mut u8 = ptr::null_mut();
            if FT_New_Face(library, c_path.as_ptr(), 0, &mut face) != 0 {
                eprintln!("Warning: could not open font {}", font_path);
                continue;
            }

            FT_Set_Pixel_Sizes(face, 0, font_size);

            let mut gindex: c_uint = 0;
            let mut char_code = FT_Get_First_Char(face, &mut gindex);
            let mut count = 0;

            while gindex != 0 {
                let cp = char_code as u32;
                if !mapping.contains_key(&cp) {
                    if let Some(bitmap) = render_char(face, cp) {
                        let next_idx = unique_glyphs.len() as u32;
                        let idx = *unique_glyphs.entry(bitmap).or_insert_with(|| {
                            glyph_data.extend_from_slice(&bitmap);
                            next_idx
                        });
                        mapping.insert(cp, idx);
                        count += 1;
                    }
                }
                char_code = FT_Get_Next_Char(face, char_code, &mut gindex);
            }

            println!("Font {}: loaded {} new glyphs", font_path, count);
            FT_Done_Face(face);
        }

        let c_jb = CString::new(FONT_PATHS[0].0).unwrap();
        let mut jb_face: *mut u8 = ptr::null_mut();
        if FT_New_Face(library, c_jb.as_ptr(), 0, &mut jb_face) == 0 {
            FT_Set_Pixel_Sizes(jb_face, 0, FONT_PATHS[0].1);
            for &(lig_name, cells, base_cp) in LIGATURES {
                if let Some(slices) = render_ligature_slices(jb_face, lig_name, cells) {
                    for (i, slice) in slices.into_iter().enumerate() {
                        let cp = base_cp + i as u32;
                        let next_idx = unique_glyphs.len() as u32;
                        let idx = if let Some(&existing) = unique_glyphs.get(&slice) {
                            existing
                        } else {
                            unique_glyphs.insert(slice, next_idx);
                            glyph_data.extend_from_slice(&slice);
                            next_idx
                        };
                        mapping.insert(cp, idx);
                    }
                } else {
                    eprintln!("Warning: could not render ligature {}", lig_name);
                }
            }
            FT_Done_Face(jb_face);
        }

        let glyph_count = unique_glyphs.len() as u32;
        let map_count = mapping.len() as u32;
        let out_path = "assets/fonts/nerd_font.bin";
        let f = File::create(out_path).expect("Unable to create output file");
        let mut w = BufWriter::new(f);

        w.write_all(&glyph_count.to_le_bytes()).unwrap();
        w.write_all(&map_count.to_le_bytes()).unwrap();
        w.write_all(&glyph_data).unwrap();

        for (&cp, &idx) in &mapping {
            w.write_all(&cp.to_le_bytes()).unwrap();
            w.write_all(&idx.to_le_bytes()).unwrap();
        }

        w.flush().unwrap();
        println!(
            "Success! Generated {} unique glyphs, {} mappings. File size: {} KB",
            glyph_count,
            map_count,
            (8 + glyph_data.len() + map_count as usize * 8) / 1024
        );

        FT_Done_FreeType(library);
    }
}
