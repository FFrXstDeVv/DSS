use std::sync::OnceLock;

const TARGET_COLUMNS: usize = 36;
const TARGET_ROWS: usize = 8;

// braille dot positions (x, y, bit)
const DOTS: [(usize, usize, u8); 8] = [
    (0, 0, 0),
    (0, 1, 1),
    (0, 2, 2),
    (1, 0, 3),
    (1, 1, 4),
    (1, 2, 5),
    (0, 3, 6),
    (1, 3, 7),
];

pub fn small_logo() -> &'static str {
    static LOGO: OnceLock<String> = OnceLock::new();

    LOGO.get_or_init(build_small_logo).as_str()
}

fn is_blank_line(line: &str) -> bool {
    line.chars()
        .all(|c| c == '\u{2800}' || c.is_ascii_whitespace())
}

fn build_small_logo() -> String {
    let mut lines = include_str!("../assets/logo.txt")
        .lines()
        .collect::<Vec<_>>();

    // remove empty Braille rows around the drawing (crops basically)
    while lines.first().is_some_and(|line| is_blank_line(line)) {
        lines.remove(0);
    }

    while lines.last().is_some_and(|line| is_blank_line(line)) {
        lines.pop();
    }

    if lines.is_empty() {
        return format!(
            "{}\n{}",
            "\u{2800}".repeat(TARGET_COLUMNS),
            "\u{2800}".repeat(TARGET_COLUMNS),
        );
    }

    let source_width = lines
        .iter()
        .map(|line| line.chars().count())
        .max()
        .unwrap_or(0)
        * 2;

    let source_height = lines.len() * 4;

    let mut pixels = vec![vec![false; source_width]; source_height];

    for (cell_y, line) in lines.iter().enumerate() {
        for (cell_x, character) in line.chars().enumerate() {
            let Some(value) = (character as u32)
                .checked_sub(0x2800)
                .filter(|value| *value <= 0xFF)
            else {
                continue;
            };

            for (dx, dy, bit) in DOTS {
                if value & (1 << bit) != 0 {
                    pixels[cell_y * 4 + dy][cell_x * 2 + dx] = true;
                }
            }
        }
    }

    // find the drawing boundaries
    let mut bounds: Option<(usize, usize, usize, usize)> = None;

    for (y, row) in pixels.iter().enumerate() {
        for (x, &filled) in row.iter().enumerate() {
            if !filled {
                continue;
            }

            bounds = Some(match bounds {
                None => (x, y, x, y),
                Some((min_x, min_y, max_x, max_y)) => {
                    (min_x.min(x), min_y.min(y), max_x.max(x), max_y.max(y))
                }
            });
        }
    }

    let Some((min_x, min_y, max_x, max_y)) = bounds else {
        return format!(
            "{}\n{}",
            "\u{2800}".repeat(TARGET_COLUMNS),
            "\u{2800}".repeat(TARGET_COLUMNS),
        );
    };

    let source_crop_width = max_x - min_x + 1;
    let source_crop_height = max_y - min_y + 1;

    let target_width = TARGET_COLUMNS * 2;
    let target_height = TARGET_ROWS * 4;

    let mut scaled = vec![vec![false; target_width]; target_height];

    // scaling
    for y in 0..target_height {
        for x in 0..target_width {
            let source_x =
                min_x + (x * source_crop_width / target_width).min(source_crop_width - 1);

            let source_y =
                min_y + (y * source_crop_height / target_height).min(source_crop_height - 1);

            scaled[y][x] = pixels[source_y][source_x];
        }
    }

    let mut output = String::new();

    for cell_y in 0..TARGET_ROWS {
        for cell_x in 0..TARGET_COLUMNS {
            let mut value = 0u32;

            for (dx, dy, bit) in DOTS {
                if scaled[cell_y * 4 + dy][cell_x * 2 + dx] {
                    value |= 1 << bit;
                }
            }

            output.push(char::from_u32(0x2800 + value).expect("valid Braille character"));
        }

        if cell_y + 1 < TARGET_ROWS {
            output.push('\n');
        }
    }

    output
}
