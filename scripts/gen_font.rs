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
    (
        "/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Medium.ttf",
        15,
    ),
    ("/usr/share/fonts/TTF/NotoSansMNerdFontMono-Medium.ttf", 15),
    ("/usr/share/fonts/TTF/DejaVuSansMono.ttf", 14),
    (
        "/usr/share/fonts/IosevkaNerdFont/IosevkaNerdFontMono-Medium.ttf",
        16,
    ),
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

fn bilinear_scale(
    bm_buf: *const u8,
    bm_width: i32,
    bm_rows: i32,
    bm_pitch: i32,
    target_w: i32,
    target_h: i32,
) -> Vec<u8> {
    let mut out = vec![0u8; (target_w * target_h) as usize];
    let scale_x = bm_width as f32 / target_w as f32;
    let scale_y = bm_rows as f32 / target_h as f32;
    for r in 0..target_h {
        let src_y = (r as f32 + 0.5) * scale_y - 0.5;
        let y0 = (src_y.floor() as i32).clamp(0, bm_rows - 1);
        let y1 = (y0 + 1).clamp(0, bm_rows - 1);
        let wy = (src_y - y0 as f32).clamp(0.0, 1.0);
        for c in 0..target_w {
            let src_x = (c as f32 + 0.5) * scale_x - 0.5;
            let x0 = (src_x.floor() as i32).clamp(0, bm_width - 1);
            let x1 = (x0 + 1).clamp(0, bm_width - 1);
            let wx = (src_x - x0 as f32).clamp(0.0, 1.0);

            unsafe {
                let p00 = *bm_buf.offset((y0 * bm_pitch + x0) as isize) as f32;
                let p01 = *bm_buf.offset((y0 * bm_pitch + x1) as isize) as f32;
                let p10 = *bm_buf.offset((y1 * bm_pitch + x0) as isize) as f32;
                let p11 = *bm_buf.offset((y1 * bm_pitch + x1) as isize) as f32;

                let top_val = (1.0 - wx) * p00 + wx * p01;
                let bot_val = (1.0 - wx) * p10 + wx * p11;
                let val = (1.0 - wy) * top_val + wy * bot_val;
                out[(r * target_w + c) as usize] = val.round().clamp(0.0, 255.0) as u8;
            }
        }
    }
    out
}

#[derive(Copy, Clone, PartialEq, Eq, Debug)]
enum BoxStyle {
    Off,
    Light,
    Heavy,
    Double,
}

fn box_arms(cp: u32) -> Option<(BoxStyle, BoxStyle, BoxStyle, BoxStyle)> {
    use BoxStyle::*;
    let res = match cp {
        0x2500 => (Off, Off, Light, Light),
        0x2501 => (Off, Off, Heavy, Heavy),
        0x2502 => (Light, Light, Off, Off),
        0x2503 => (Heavy, Heavy, Off, Off),
        0x250C => (Off, Light, Off, Light),
        0x250D => (Off, Light, Off, Heavy),
        0x250E => (Off, Heavy, Off, Light),
        0x250F => (Off, Heavy, Off, Heavy),
        0x2510 => (Off, Light, Light, Off),
        0x2511 => (Off, Light, Heavy, Off),
        0x2512 => (Off, Heavy, Light, Off),
        0x2513 => (Off, Heavy, Heavy, Off),
        0x2514 => (Light, Off, Off, Light),
        0x2515 => (Light, Off, Off, Heavy),
        0x2516 => (Heavy, Off, Off, Light),
        0x2517 => (Heavy, Off, Off, Heavy),
        0x2518 => (Light, Off, Light, Off),
        0x2519 => (Light, Off, Heavy, Off),
        0x251A => (Heavy, Off, Light, Off),
        0x251B => (Heavy, Off, Heavy, Off),
        0x251C => (Light, Light, Off, Light),
        0x251D => (Light, Light, Off, Heavy),
        0x251E => (Heavy, Light, Off, Light),
        0x251F => (Light, Heavy, Off, Light),
        0x2520 => (Heavy, Heavy, Off, Light),
        0x2521 => (Light, Heavy, Off, Heavy),
        0x2522 => (Heavy, Light, Off, Heavy),
        0x2523 => (Heavy, Heavy, Off, Heavy),
        0x2524 => (Light, Light, Light, Off),
        0x2525 => (Light, Light, Heavy, Off),
        0x2526 => (Heavy, Light, Light, Off),
        0x2527 => (Light, Heavy, Light, Off),
        0x2528 => (Heavy, Heavy, Light, Off),
        0x2529 => (Light, Heavy, Heavy, Off),
        0x252A => (Heavy, Light, Heavy, Off),
        0x252B => (Heavy, Heavy, Heavy, Off),
        0x252C => (Off, Light, Light, Light),
        0x252D => (Off, Light, Heavy, Light),
        0x252E => (Off, Light, Light, Heavy),
        0x252F => (Off, Light, Heavy, Heavy),
        0x2530 => (Off, Heavy, Light, Light),
        0x2531 => (Off, Heavy, Heavy, Light),
        0x2532 => (Off, Heavy, Light, Heavy),
        0x2533 => (Off, Heavy, Heavy, Heavy),
        0x2534 => (Light, Off, Light, Light),
        0x2535 => (Light, Off, Heavy, Light),
        0x2536 => (Light, Off, Light, Heavy),
        0x2537 => (Light, Off, Heavy, Heavy),
        0x2538 => (Heavy, Off, Light, Light),
        0x2539 => (Heavy, Off, Heavy, Light),
        0x253A => (Heavy, Off, Light, Heavy),
        0x253B => (Heavy, Off, Heavy, Heavy),
        0x253C => (Light, Light, Light, Light),
        0x253D => (Light, Light, Heavy, Light),
        0x253E => (Light, Light, Light, Heavy),
        0x253F => (Light, Light, Heavy, Heavy),
        0x2540 => (Heavy, Light, Light, Light),
        0x2541 => (Light, Heavy, Light, Light),
        0x2542 => (Heavy, Heavy, Light, Light),
        0x2543 => (Heavy, Light, Heavy, Light),
        0x2544 => (Heavy, Light, Light, Heavy),
        0x2545 => (Light, Heavy, Heavy, Light),
        0x2546 => (Light, Heavy, Light, Heavy),
        0x2547 => (Light, Heavy, Heavy, Heavy),
        0x2548 => (Heavy, Light, Heavy, Heavy),
        0x2549 => (Heavy, Heavy, Heavy, Light),
        0x254A => (Heavy, Heavy, Light, Heavy),
        0x254B => (Heavy, Heavy, Heavy, Heavy),
        0x2550 => (Off, Off, Double, Double),
        0x2551 => (Double, Double, Off, Off),
        0x2552 => (Off, Light, Off, Double),
        0x2553 => (Off, Double, Off, Light),
        0x2554 => (Off, Double, Off, Double),
        0x2555 => (Off, Light, Double, Off),
        0x2556 => (Off, Double, Light, Off),
        0x2557 => (Off, Double, Double, Off),
        0x2558 => (Light, Off, Off, Double),
        0x2559 => (Double, Off, Off, Light),
        0x255A => (Double, Off, Off, Double),
        0x255B => (Light, Off, Double, Off),
        0x255C => (Double, Off, Light, Off),
        0x255D => (Double, Off, Double, Off),
        0x255E => (Light, Light, Off, Double),
        0x255F => (Double, Double, Off, Light),
        0x2560 => (Double, Double, Off, Double),
        0x2561 => (Light, Light, Double, Off),
        0x2562 => (Double, Double, Light, Off),
        0x2563 => (Double, Double, Double, Off),
        0x2564 => (Off, Light, Double, Double),
        0x2565 => (Off, Double, Light, Light),
        0x2566 => (Off, Double, Double, Double),
        0x2567 => (Light, Off, Double, Double),
        0x2568 => (Double, Off, Light, Light),
        0x2569 => (Double, Off, Double, Double),
        0x256A => (Light, Light, Double, Double),
        0x256B => (Double, Double, Light, Light),
        0x256C => (Double, Double, Double, Double),
        0x2574 => (Off, Off, Light, Off),
        0x2575 => (Light, Off, Off, Off),
        0x2576 => (Off, Off, Off, Light),
        0x2577 => (Off, Light, Off, Off),
        0x2578 => (Off, Off, Heavy, Off),
        0x2579 => (Heavy, Off, Off, Off),
        0x257A => (Off, Off, Off, Heavy),
        0x257B => (Off, Heavy, Off, Off),
        0x257C => (Off, Off, Light, Heavy),
        0x257D => (Light, Heavy, Off, Off),
        0x257E => (Off, Off, Heavy, Light),
        0x257F => (Heavy, Light, Off, Off),
        _ => return None,
    };
    Some(res)
}

fn render_box(up: BoxStyle, down: BoxStyle, left: BoxStyle, right: BoxStyle) -> [u8; BPG] {
    let mut raw = [0u8; BPG];

    if up == BoxStyle::Off
        && down == BoxStyle::Double
        && left == BoxStyle::Off
        && right == BoxStyle::Double
    {
        for y in 6..=7 {
            for x in 2..10 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 12..=13 {
            for x in 6..10 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 6..20 {
            for x in 2..=3 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 12..20 {
            for x in 6..=7 {
                raw[y * WIDTH + x] = 255;
            }
        }
        return raw;
    }
    if up == BoxStyle::Off
        && down == BoxStyle::Double
        && left == BoxStyle::Double
        && right == BoxStyle::Off
    {
        for y in 6..=7 {
            for x in 0..=7 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 12..=13 {
            for x in 0..=3 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 6..20 {
            for x in 6..=7 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 12..20 {
            for x in 2..=3 {
                raw[y * WIDTH + x] = 255;
            }
        }
        return raw;
    }
    if up == BoxStyle::Double
        && down == BoxStyle::Off
        && left == BoxStyle::Off
        && right == BoxStyle::Double
    {
        for y in 12..=13 {
            for x in 2..10 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 6..=7 {
            for x in 6..10 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 0..=13 {
            for x in 2..=3 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 0..=7 {
            for x in 6..=7 {
                raw[y * WIDTH + x] = 255;
            }
        }
        return raw;
    }
    if up == BoxStyle::Double
        && down == BoxStyle::Off
        && left == BoxStyle::Double
        && right == BoxStyle::Off
    {
        for y in 12..=13 {
            for x in 0..=7 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 6..=7 {
            for x in 0..=3 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 0..=13 {
            for x in 6..=7 {
                raw[y * WIDTH + x] = 255;
            }
        }
        for y in 0..=7 {
            for x in 2..=3 {
                raw[y * WIDTH + x] = 255;
            }
        }
        return raw;
    }

    let draw_h = |raw: &mut [u8; BPG], style: BoxStyle, x_start: usize, x_end: usize| match style {
        BoxStyle::Light => {
            for y in 9..=10 {
                for x in x_start..=x_end {
                    raw[y * WIDTH + x] = 255;
                }
            }
        }
        BoxStyle::Heavy => {
            for y in 8..=11 {
                for x in x_start..=x_end {
                    raw[y * WIDTH + x] = 255;
                }
            }
        }
        BoxStyle::Double => {
            for y in 6..=7 {
                for x in x_start..=x_end {
                    raw[y * WIDTH + x] = 255;
                }
            }
            for y in 12..=13 {
                for x in x_start..=x_end {
                    raw[y * WIDTH + x] = 255;
                }
            }
        }
        BoxStyle::Off => {}
    };

    let draw_v = |raw: &mut [u8; BPG], style: BoxStyle, y_start: usize, y_end: usize| match style {
        BoxStyle::Light => {
            for y in y_start..=y_end {
                for x in 4..=5 {
                    raw[y * WIDTH + x] = 255;
                }
            }
        }
        BoxStyle::Heavy => {
            for y in y_start..=y_end {
                for x in 3..=6 {
                    raw[y * WIDTH + x] = 255;
                }
            }
        }
        BoxStyle::Double => {
            for y in y_start..=y_end {
                for x in 2..=3 {
                    raw[y * WIDTH + x] = 255;
                }
                for x in 6..=7 {
                    raw[y * WIDTH + x] = 255;
                }
            }
        }
        BoxStyle::Off => {}
    };

    if up != BoxStyle::Off {
        draw_v(&mut raw, up, 0, 9);
    }
    if down != BoxStyle::Off {
        draw_v(&mut raw, down, 10, 19);
    }
    if left != BoxStyle::Off {
        draw_h(&mut raw, left, 0, 4);
    }
    if right != BoxStyle::Off {
        draw_h(&mut raw, right, 5, 9);
    }

    if (up != BoxStyle::Off || down != BoxStyle::Off)
        && (left != BoxStyle::Off || right != BoxStyle::Off)
    {
        let v_style = if up != BoxStyle::Off { up } else { down };
        let h_style = if left != BoxStyle::Off { left } else { right };

        if v_style == BoxStyle::Double && h_style == BoxStyle::Double {
        } else if v_style == BoxStyle::Double {
            draw_h(&mut raw, h_style, 2, 7);
        } else if h_style == BoxStyle::Double {
            draw_v(&mut raw, v_style, 6, 13);
        } else {
            let x_range = if v_style == BoxStyle::Heavy
                || (up == BoxStyle::Heavy && down == BoxStyle::Heavy)
            {
                3..=6
            } else {
                4..=5
            };
            let y_range = if h_style == BoxStyle::Heavy
                || (left == BoxStyle::Heavy && right == BoxStyle::Heavy)
            {
                8..=11
            } else {
                9..=10
            };
            for y in y_range {
                for x in x_range.clone() {
                    raw[y * WIDTH + x] = 255;
                }
            }
        }
    }

    raw
}

fn render_geometric(cp: u32) -> Option<[u8; BPG]> {
    let mut raw = [0u8; BPG];
    if (0x2580..=0x259F).contains(&cp) {
        if cp == 0x2588 {
            return Some([255u8; BPG]);
        }
        if (0x2581..=0x2587).contains(&cp) {
            let h = [2, 5, 8, 10, 12, 15, 18][(cp - 0x2581) as usize];
            for y in (HEIGHT - h)..HEIGHT {
                for x in 0..WIDTH {
                    raw[y * WIDTH + x] = 255;
                }
            }
            return Some(raw);
        }
        if cp == 0x2580 {
            for y in 0..10 {
                for x in 0..WIDTH {
                    raw[y * WIDTH + x] = 255;
                }
            }
            return Some(raw);
        }
        if (0x2589..=0x258F).contains(&cp) {
            let w = [9, 8, 6, 5, 4, 2, 1][(cp - 0x2589) as usize];
            for y in 0..HEIGHT {
                for x in 0..w {
                    raw[y * WIDTH + x] = 255;
                }
            }
            return Some(raw);
        }
        if cp == 0x2590 {
            for y in 0..HEIGHT {
                for x in 5..WIDTH {
                    raw[y * WIDTH + x] = 255;
                }
            }
            return Some(raw);
        }
        if cp == 0x2594 {
            for y in 0..2 {
                for x in 0..WIDTH {
                    raw[y * WIDTH + x] = 255;
                }
            }
            return Some(raw);
        }
        if cp == 0x2595 {
            for y in 0..HEIGHT {
                raw[y * WIDTH + 9] = 255;
            }
            return Some(raw);
        }
        if cp == 0x2591 {
            for y in 0..HEIGHT {
                for x in 0..WIDTH {
                    if (x % 2 == 0) && (y % 2 == 0) {
                        raw[y * WIDTH + x] = 255;
                    }
                }
            }
            return Some(raw);
        }
        if cp == 0x2592 {
            for y in 0..HEIGHT {
                for x in 0..WIDTH {
                    if (x + y) % 2 == 0 {
                        raw[y * WIDTH + x] = 255;
                    }
                }
            }
            return Some(raw);
        }
        if cp == 0x2593 {
            for y in 0..HEIGHT {
                for x in 0..WIDTH {
                    if !((x % 2 == 0) && (y % 2 == 0)) {
                        raw[y * WIDTH + x] = 255;
                    }
                }
            }
            return Some(raw);
        }
        let quad_mask: Option<u8> = match cp {
            0x2596 => Some(4),
            0x2597 => Some(8),
            0x2598 => Some(1),
            0x2599 => Some(1 | 4 | 8),
            0x259A => Some(1 | 8),
            0x259B => Some(1 | 2 | 4),
            0x259C => Some(1 | 2 | 8),
            0x259D => Some(2),
            0x259E => Some(2 | 4),
            0x259F => Some(2 | 4 | 8),
            _ => None,
        };
        if let Some(mask) = quad_mask {
            for y in 0..HEIGHT {
                for x in 0..WIDTH {
                    let bit = if y < 10 && x < 5 {
                        1
                    } else if y < 10 && x >= 5 {
                        2
                    } else if y >= 10 && x < 5 {
                        4
                    } else {
                        8
                    };
                    if mask & bit != 0 {
                        raw[y * WIDTH + x] = 255;
                    }
                }
            }
            return Some(raw);
        }
    }

    if let Some((u, d, l, r)) = box_arms(cp) {
        return Some(render_box(u, d, l, r));
    }

    match cp {
        0x2504 => {
            for y in 9..=10 {
                for x in [0, 1, 4, 5, 8, 9] {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x2505 => {
            for y in 8..=11 {
                for x in [0, 1, 4, 5, 8, 9] {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x2506 => {
            for x in 4..=5 {
                for y in 1..=4 {
                    raw[y * WIDTH + x] = 255;
                }
                for y in 8..=11 {
                    raw[y * WIDTH + x] = 255;
                }
                for y in 15..=18 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x2507 => {
            for x in 3..=6 {
                for y in 1..=4 {
                    raw[y * WIDTH + x] = 255;
                }
                for y in 8..=11 {
                    raw[y * WIDTH + x] = 255;
                }
                for y in 15..=18 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x2508 => {
            for y in 9..=10 {
                for x in [0, 1, 3, 4, 6, 8, 9] {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x2509 => {
            for y in 8..=11 {
                for x in [0, 1, 3, 4, 6, 8, 9] {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x250A => {
            for x in 4..=5 {
                for y in [1, 2, 6, 7, 11, 12, 16, 17] {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x250B => {
            for x in 3..=6 {
                for y in [1, 2, 6, 7, 11, 12, 16, 17] {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x254C => {
            for y in 9..=10 {
                for x in 1..=3 {
                    raw[y * WIDTH + x] = 255;
                }
                for x in 6..=8 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x254D => {
            for y in 8..=11 {
                for x in 1..=3 {
                    raw[y * WIDTH + x] = 255;
                }
                for x in 6..=8 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x254E => {
            for x in 4..=5 {
                for y in 2..=7 {
                    raw[y * WIDTH + x] = 255;
                }
                for y in 12..=17 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x254F => {
            for x in 3..=6 {
                for y in 2..=7 {
                    raw[y * WIDTH + x] = 255;
                }
                for y in 12..=17 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x256D => {
            for y in 9..=10 {
                for x in 6..10 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            raw[10 * WIDTH + 5] = 255;
            raw[11 * WIDTH + 5] = 255;
            raw[11 * WIDTH + 4] = 255;
            raw[12 * WIDTH + 4] = 255;
            raw[12 * WIDTH + 5] = 255;
            raw[13 * WIDTH + 4] = 255;
            raw[13 * WIDTH + 5] = 255;
            for y in 14..20 {
                for x in 4..=5 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x256E => {
            for y in 9..=10 {
                for x in 0..=3 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            raw[10 * WIDTH + 4] = 255;
            raw[11 * WIDTH + 4] = 255;
            raw[11 * WIDTH + 5] = 255;
            raw[12 * WIDTH + 4] = 255;
            raw[12 * WIDTH + 5] = 255;
            raw[13 * WIDTH + 4] = 255;
            raw[13 * WIDTH + 5] = 255;
            for y in 14..20 {
                for x in 4..=5 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x256F => {
            for y in 9..=10 {
                for x in 0..=3 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            raw[9 * WIDTH + 4] = 255;
            raw[8 * WIDTH + 4] = 255;
            raw[8 * WIDTH + 5] = 255;
            raw[7 * WIDTH + 4] = 255;
            raw[7 * WIDTH + 5] = 255;
            raw[6 * WIDTH + 4] = 255;
            raw[6 * WIDTH + 5] = 255;
            for y in 0..6 {
                for x in 4..=5 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x2570 => {
            for y in 9..=10 {
                for x in 6..10 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            raw[9 * WIDTH + 5] = 255;
            raw[8 * WIDTH + 5] = 255;
            raw[8 * WIDTH + 4] = 255;
            raw[7 * WIDTH + 4] = 255;
            raw[7 * WIDTH + 5] = 255;
            raw[6 * WIDTH + 4] = 255;
            raw[6 * WIDTH + 5] = 255;
            for y in 0..6 {
                for x in 4..=5 {
                    raw[y * WIDTH + x] = 255;
                }
            }
            Some(raw)
        }
        0x2571 => {
            for y in 0..20 {
                let x = ((19 - y) * 9 + 9) / 19;
                raw[y * WIDTH + x] = 255;
                if x > 0 {
                    raw[y * WIDTH + x - 1] = 180;
                }
            }
            Some(raw)
        }
        0x2572 => {
            for y in 0..20 {
                let x = (y * 9 + 9) / 19;
                raw[y * WIDTH + x] = 255;
                if x + 1 < WIDTH {
                    raw[y * WIDTH + x + 1] = 180;
                }
            }
            Some(raw)
        }
        0x2573 => {
            let mut r1 = render_geometric(0x2571).unwrap();
            let r2 = render_geometric(0x2572).unwrap();
            for i in 0..BPG {
                r1[i] = r1[i].max(r2[i]);
            }
            Some(r1)
        }
        _ => None,
    }
}

unsafe fn render_char(face: *mut u8, cp: u32, default_size: c_uint) -> Option<[u8; BPG]> {
    let is_icon = ((0xE000..=0xF8FF).contains(&cp) || (0xF0000..=0x10FFFF).contains(&cp))
        && !(0xE0A0..=0xE0D4).contains(&cp);
    if is_icon {
        FT_Set_Pixel_Sizes(face, 0, 20);
    }
    let load_res = FT_Load_Char(face, cp as c_ulong, FT_LOAD_RENDER);
    if is_icon {
        FT_Set_Pixel_Sizes(face, 0, default_size);
    }
    if load_res != 0 {
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

        let (target_w, target_h) = if is_icon {
            let aspect = bm_width as f32 / bm_rows as f32;
            if aspect > 1.4 {
                let w = 10;
                let h = ((10.0 / aspect).round() as i32).clamp(1, 14);
                (w, h)
            } else {
                let h = 14;
                let w = ((14.0 * aspect).round() as i32).clamp(1, 10);
                (w, h)
            }
        } else if bm_width > WIDTH as i32 || bm_rows > HEIGHT as i32 {
            let scale = (bm_width as f32 / WIDTH as f32).max(bm_rows as f32 / HEIGHT as f32);
            let tw = ((bm_width as f32 / scale).round() as i32).clamp(1, WIDTH as i32);
            let th = ((bm_rows as f32 / scale).round() as i32).clamp(1, HEIGHT as i32);
            (tw, th)
        } else {
            (bm_width, bm_rows)
        };

        if is_icon || bm_width > WIDTH as i32 || bm_rows > HEIGHT as i32 {
            let dst_x0 = (WIDTH as i32 - target_w) / 2;
            let dst_y0 = (HEIGHT as i32 - target_h) / 2;

            let scaled = bilinear_scale(bm_buf, bm_width, bm_rows, bm_pitch, target_w, target_h);
            for r in 0..target_h {
                for c in 0..target_w {
                    raw[(dst_y0 + r) as usize * WIDTH + (dst_x0 + c) as usize] =
                        scaled[(r * target_w + c) as usize];
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

    Some(raw)
}

unsafe fn render_ligature_slices(
    face: *mut u8,
    name: &str,
    cells: usize,
) -> Option<Vec<[u8; BPG]>> {
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

        for cp in 0x2580..=0x259F {
            if let Some(bitmap) = render_geometric(cp) {
                let next_idx = unique_glyphs.len() as u32;
                let idx = *unique_glyphs.entry(bitmap).or_insert_with(|| {
                    glyph_data.extend_from_slice(&bitmap);
                    next_idx
                });
                mapping.insert(cp, idx);
            }
        }
        for cp in 0x2500..=0x257F {
            if let Some(bitmap) = render_geometric(cp) {
                let next_idx = unique_glyphs.len() as u32;
                let idx = *unique_glyphs.entry(bitmap).or_insert_with(|| {
                    glyph_data.extend_from_slice(&bitmap);
                    next_idx
                });
                mapping.insert(cp, idx);
            }
        }

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
                    if let Some(bitmap) = render_char(face, cp, font_size) {
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
