use serde::{Deserialize, Serialize};
use serde_json::Deserializer;

#[derive(Debug, Serialize, Deserialize)]
pub struct ToolRequest {
    pub r#type: String, // "tool_request"
    pub tool: String,   // "filesystem.read"
    pub arguments: std::collections::HashMap<String, String>,
    pub reason: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ToolResponse {
    pub r#type: String, // "tool_response"
    pub success: bool,
    pub content: String,
}

/// Extract the first valid `ToolRequest` from a string that may contain
/// surrounding text, code snippets with braces, or multiple JSON objects.
///
/// Uses `serde_json::Deserializer::into_iter` to parse a stream of JSON
/// values from the input, returning the first one that successfully
/// deserialises as a `ToolRequest` with `r#type == "tool_request"`.
pub fn parse_tool_request(json_str: &str) -> Option<ToolRequest> {
    // Locate the first opening brace — everything before it is preamble.
    let start = json_str.find('{')?;
    let tail = &json_str[start..];

    // Feed the tail into serde_json's streaming deserializer so that each
    // top-level JSON value is tried independently.  This avoids the greedy
    // `rfind('}')` problem: if `tail` contains `{...} fn main() { println!() }`,
    // the first `{...}` is parsed as one value and the rest is ignored.
    let stream = Deserializer::from_str(tail).into_iter::<serde_json::Value>();
    for item in stream {
        let value = match item {
            Ok(v) => v,
            _ => continue,
        };
        // Quick structural check before full deserialisation.
        if !value.is_object() {
            continue;
        }
        let obj = value.as_object().unwrap();
        if obj.get("type").and_then(|v| v.as_str()) != Some("tool_request") {
            continue;
        }
        // Convert the Value back to a string and deserialise properly.
        // This is safe because we already validated the structure.
        if let Ok(req) = serde_json::from_value::<ToolRequest>(value) {
            return Some(req);
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extracts_valid_tool_request_from_plain_text() {
        let input = r#"{"type": "tool_request", "tool": "filesystem.read", "arguments": {"path": "/tmp"}, "reason": "check file"}"#;
        let req = parse_tool_request(input).unwrap();
        assert_eq!(req.tool, "filesystem.read");
        assert_eq!(req.arguments.get("path").unwrap(), "/tmp");
    }

    #[test]
    fn test_extracts_tool_request_from_text_with_trailing_braces() {
        // The key test: trailing code / reasoning with braces must NOT break extraction.
        let input = r#"Here is my action: {"type": "tool_request", "tool": "filesystem.read", "arguments": {}, "reason": "test"} and here is some code: fn foo() { println!("bar"); }"#;
        let req = parse_tool_request(input).unwrap();
        assert_eq!(req.tool, "filesystem.read");
        assert_eq!(req.r#type, "tool_request");
    }

    #[test]
    fn test_extracts_first_tool_request_when_multiple_objects_present() {
        let input = r#"{"type": "tool_request", "tool": "filesystem.read", "arguments": {}, "reason": "first"} trailing {"type": "tool_request", "tool": "filesystem.write", "arguments": {}, "reason": "second"}"#;
        let req = parse_tool_request(input).unwrap();
        assert_eq!(req.reason, "first");
    }

    #[test]
    fn test_ignores_invalid_tool_request() {
        // Valid JSON but wrong type field.
        let input = r#"{"type": "chat", "message": "hello"}"#;
        assert!(parse_tool_request(input).is_none());
    }

    #[test]
    fn test_returns_none_for_no_brace() {
        assert!(parse_tool_request("just plain text").is_none());
    }

    #[test]
    fn test_returns_none_for_empty_string() {
        assert!(parse_tool_request("").is_none());
    }
}
