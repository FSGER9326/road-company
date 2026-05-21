import json
import os
import math

class EventSystem:
    def __init__(self):
        self.templates = []
        self._last_fired = {}
        
    def configure(self, event_templates):
        self.templates = event_templates
        self._last_fired = {}
        
    def evaluate_and_fire(self, world_state, current_tick):
        candidates = []
        context_route = world_state.get("context_route", {})
        context_settlement = world_state.get("context_settlement", {})
        
        for template in self.templates:
            event_id = template.get("id", "")
            cooldown = int(template.get("cooldown_days", 0))
            ticks_passed = current_tick - self._last_fired.get(event_id, -9999)
            if ticks_passed < cooldown:
                continue
                
            category = template.get("category", "")
            if category == "settlement":
                for settlement in world_state.get("settlements", []):
                    if self._check_conditions(settlement, template.get("trigger_conditions", [])):
                        candidates.append(self._build_candidate(template, settlement, None, None))
            elif category == "route":
                for route in world_state.get("routes", []):
                    if self._check_conditions(route, template.get("trigger_conditions", [])):
                        candidates.append(self._build_candidate(template, None, route, None))
            elif category == "company":
                company = world_state.get("company", {})
                if company and self._check_conditions(company, template.get("trigger_conditions", [])):
                    candidates.append(self._build_candidate(template, context_settlement or None, context_route or None, company))
                    
        # Sort candidates by weight descending
        candidates.sort(key=lambda x: int(x["template"].get("weight", 0)), reverse=True)
        
        fired = []
        for candidate in candidates:
            if len(fired) >= 3:
                break
            event_id = candidate["template"].get("id", "")
            if event_id in self._last_fired:
                ticks_passed = current_tick - self._last_fired.get(event_id, -9999)
                if ticks_passed < int(candidate["template"].get("cooldown_days", 0)):
                    continue
                    
            self._last_fired[event_id] = current_tick
            self._apply_mechanical_effects(candidate)
            fired.append(candidate)
            
        return fired
        
    def _check_conditions(self, target, conditions):
        for cond in conditions:
            field = cond.get("field", "")
            op = cond.get("op", "")
            target_val = cond.get("value")
            actual_val = target.get(field)
            if actual_val is None:
                actual_val = 0
                if isinstance(target_val, bool):
                    actual_val = False
                elif isinstance(target_val, str):
                    actual_val = ""
                    
            passed = False
            if isinstance(target_val, (int, float)):
                act_f = float(actual_val)
                tgt_f = float(target_val)
                if op == "lt": passed = act_f < tgt_f
                elif op == "lte": passed = act_f <= tgt_f
                elif op == "gt": passed = act_f > tgt_f
                elif op == "gte": passed = act_f >= tgt_f
                elif op == "eq": passed = act_f == tgt_f
                elif op == "neq": passed = act_f != tgt_f
            else:
                if op == "eq": passed = actual_val == target_val
                elif op == "neq": passed = actual_val != target_val
                
            if not passed:
                return False
        return True
        
    def _build_candidate(self, template, settlement, route, company):
        return {
            "template": template,
            "settlement": settlement,
            "route": route,
            "company": company,
            "settlement_name": settlement.get("name", settlement.get("settlement_id", "")) if settlement else "",
            "route_name": route.get("name", route.get("route_id", "")) if route else ""
        }
        
    def _apply_mechanical_effects(self, candidate):
        effects = candidate["template"].get("mechanical_effects", {})
        target = None
        if candidate["template"].get("category", "") == "settlement":
            target = candidate["settlement"]
        elif candidate["template"].get("category", "") == "route":
            target = candidate["route"]
        elif candidate["template"].get("category", "") == "company":
            target = candidate["company"]
            
        if target is None:
            return
            
        for field, val in effects.items():
            if isinstance(val, (bool, str)):
                target[field] = val
            else:
                current = float(target.get(field, 0))
                target[field] = current + float(val)
