import json
import os
import sys

def validate_events():
    manifest_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'world', 'event_templates.json')
    if not os.path.exists(manifest_path):
        print("Missing event_templates.json")
        sys.exit(1)
        
    with open(manifest_path, 'r', encoding='utf-8') as f:
        try:
            events = json.load(f)
        except json.JSONDecodeError as e:
            print(f"JSON Parse Error in event_templates.json: {e}")
            sys.exit(1)
            
    if not isinstance(events, list):
        print("event_templates.json must contain a list.")
        sys.exit(1)
        
    valid_ops = {"lt", "lte", "gt", "gte", "eq", "neq"}
    valid_categories = {"settlement", "route", "company"}
    
    for event in events:
        event_id = event.get("id")
        if not event_id:
            print("Event missing 'id'")
            sys.exit(1)
            
        if event.get("category") not in valid_categories:
            print(f"Event {event_id} has invalid category {event.get('category')}")
            sys.exit(1)
            
        for cond in event.get("trigger_conditions", []):
            if "field" not in cond or "op" not in cond or "value" not in cond:
                print(f"Event {event_id} has malformed trigger condition")
                sys.exit(1)
            if cond["op"] not in valid_ops:
                print(f"Event {event_id} uses invalid op {cond['op']}")
                sys.exit(1)
                
    print("Event template validation passed.")

if __name__ == "__main__":
    validate_events()
