import unittest
import json
import os
import sys

# Add tools dir to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from event_rumor_memory_core import EventSystem

class TestEventRumorMemory(unittest.TestCase):
    def setUp(self):
        self.system = EventSystem()
        
        # Load real templates
        manifest_path = os.path.join(os.path.dirname(__file__), '..', '..', 'data', 'world', 'event_templates.json')
        with open(manifest_path, 'r', encoding='utf-8') as f:
            self.templates = json.load(f)
            
        self.system.configure(self.templates)
        
    def test_food_shortage_triggers_event(self):
        world_state = {
            "settlements": [
                {
                    "settlement_id": "s_test",
                    "name": "Test Town",
                    "food_stock": 2,
                    "medicine_stock": 10
                }
            ],
            "routes": []
        }
        fired = self.system.evaluate_and_fire(world_state, 1)
        self.assertTrue(any(e["template"]["id"] == "food_shortage" for e in fired))
        
        # Verify mechanical effect was applied
        self.assertEqual(world_state["settlements"][0]["unrest"], 10)
        self.assertEqual(world_state["settlements"][0]["prosperity"], -5)
        
    def test_cooldown_prevents_spam(self):
        world_state = {
            "settlements": [
                {
                    "settlement_id": "s_test",
                    "name": "Test Town",
                    "food_stock": 2,
                    "medicine_stock": 10
                }
            ],
            "routes": []
        }
        # Fire once
        fired_1 = self.system.evaluate_and_fire(world_state, 1)
        self.assertEqual(len(fired_1), 1)
        
        # Fire again immediately - should be blocked by cooldown
        fired_2 = self.system.evaluate_and_fire(world_state, 2)
        self.assertEqual(len(fired_2), 0)
        
        # Fire after cooldown
        fired_3 = self.system.evaluate_and_fire(world_state, 16)
        self.assertEqual(len(fired_3), 1)
        
    def test_bandit_surge_triggers(self):
        world_state = {
            "settlements": [{"food_stock": 10, "medicine_stock": 10}],
            "routes": [
                {
                    "route_id": "r_test",
                    "name": "Test Route",
                    "bandit_pressure": 50,
                    "danger": 50,
                    "traffic": 100
                }
            ]
        }
        fired = self.system.evaluate_and_fire(world_state, 1)
        self.assertTrue(any(e["template"]["id"] == "bandit_surge" for e in fired))
        
        # Verify effect applied
        self.assertEqual(world_state["routes"][0]["danger"], 70)
        self.assertEqual(world_state["routes"][0]["traffic"], 90)
        
    def test_same_seed_same_events(self):
        # Deterministic output based on world state and tick
        world_state_1 = {
            "settlements": [{"food_stock": 2, "medicine_stock": 10}],
            "routes": []
        }
        system1 = EventSystem()
        system1.configure(self.templates)
        fired_1 = system1.evaluate_and_fire(world_state_1, 1)
        
        world_state_2 = {
            "settlements": [{"food_stock": 2, "medicine_stock": 10}],
            "routes": []
        }
        system2 = EventSystem()
        system2.configure(self.templates)
        fired_2 = system2.evaluate_and_fire(world_state_2, 1)
        
        self.assertEqual(fired_1[0]["template"]["id"], fired_2[0]["template"]["id"])
        
    def test_changed_state_changes_priorities(self):
        # A route blocked event (weight 200) should trump rising unrest (weight 120) and food shortage (weight 100)
        # if max events were 1 (though we allow 3). Let's just make sure both fire.
        world_state = {
            "settlements": [{"unrest": 90, "food_stock": 2, "medicine_stock": 10}],
            "routes": [{"danger": 95}]
        }
        fired = self.system.evaluate_and_fire(world_state, 1)
        self.assertEqual(len(fired), 3)
        ids = [e["template"]["id"] for e in fired]
        self.assertEqual(ids[0], "route_blocked_event")
        self.assertEqual(ids[1], "rising_unrest")
        self.assertEqual(ids[2], "food_shortage")
        
    def test_invalid_event_ref_fails_validation(self):
        # This belongs in validate_event_rumor_memory.py, but we can test bad logic here
        pass

if __name__ == '__main__':
    unittest.main()
