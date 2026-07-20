use super::tools::ToolResponse;

pub fn format_tool_response(success: bool, content: String) -> String {
    let res = ToolResponse {
        r#type: "tool_response".into(),
        success,
        content,
    };
    serde_json::to_string(&res).unwrap_or_default()
}
