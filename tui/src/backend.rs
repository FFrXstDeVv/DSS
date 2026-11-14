use std::process::Command;

pub struct Evaluation {
    pub status: String,
    pub result: String,
}

pub fn evaluate(expression: &str) -> Result<Evaluation, String> {
    let project_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .ok_or("Cannot locate DSS project directory")?;

    let executable = project_dir.join("zig-out").join("bin").join("dss");

    let output = Command::new(&executable)
        .arg(expression)
        .output()
        .map_err(|error| {
            format!(
                "Cannot execute DSS Core at {}: {error}",
                executable.display()
            )
        })?;

    // zig currently writes std.debug.print output to stderr
    let text = if output.stderr.is_empty() {
        String::from_utf8_lossy(&output.stdout)
    } else {
        String::from_utf8_lossy(&output.stderr)
    };

    let status = text
        .lines()
        .find_map(|line| line.strip_prefix("STATUS: "))
        .ok_or_else(|| format!("Invalid response from DSS Core: {text}"))?
        .to_string();

    let result = text
        .lines()
        .find_map(|line| line.strip_prefix("RESULT: "))
        .map(str::to_string)
        .unwrap_or_else(|| {
            text.lines()
                .skip_while(|line| !line.starts_with("STATUS: "))
                .skip(1)
                .collect::<Vec<_>>()
                .join("\n")
        });

    Ok(Evaluation { status, result })
}
