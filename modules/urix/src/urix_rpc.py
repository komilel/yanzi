"""urix — JSON-RPC protocol helpers."""

import json


def encode_request(method, params=None, req_id=1):
    msg = {"method": method, "id": req_id}
    if params:
        msg["params"] = params
    return json.dumps(msg, ensure_ascii=False) + "\n"


def encode_response(result, req_id):
    return json.dumps({"result": result, "id": req_id}, ensure_ascii=False) + "\n"


def encode_error(code, message, req_id):
    return json.dumps({"error": {"code": code, "message": message}, "id": req_id}, ensure_ascii=False) + "\n"


def encode_event(event, data):
    return json.dumps({"event": event, "data": data}, ensure_ascii=False) + "\n"


def parse_message(line):
    """Parse a JSON-RPC message line. Returns dict or None on error."""
    try:
        if isinstance(line, bytes):
            line = line.decode(errors="replace")
        return json.loads(line.strip())
    except (json.JSONDecodeError, UnicodeDecodeError):
        return None
