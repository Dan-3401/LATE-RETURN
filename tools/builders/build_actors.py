"""Builds scenes/enemies/zombie.tscn."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tscn import Scene, V2, Col, SN, NP, Raw  # noqa: E402

STATES = ["Idle", "Wander", "Patrol", "PatrolResume", "Suspicious", "Investigate", "Alert", "Chase", "Attack", "Search", "Return", "Feed", "Dead"]
FILES = {"PatrolResume": "patrol_resume"}


def build_zombie():
    sc = Scene()
    sc.node("Zombie", "CharacterBody2D", None, {
        "collision_layer": 4, "collision_mask": 1, "floor_snap_length": 4.0,
        "script": sc.ext_res("Script", "res://scripts/actors/zombie.gd"),
        "data": sc.ext_res("Resource", "res://resources/enemies/zombie_default.tres"),
        "frames": sc.ext_res("SpriteFrames", "res://art/characters/zombie_a/zombie_a_frames.tres"),
    })
    shape = sc.sub_res("RectangleShape2D", {"size": V2(12, 38)})
    sc.node("CollisionShape2D", "CollisionShape2D", ".", {"position": V2(0, -19), "shape": shape})
    sc.node("Visual", "Node2D", ".", {})
    sc.node("Body", "AnimatedSprite2D", "Visual", {
        "position": V2(0, -24),
        "sprite_frames": sc.ext_res("SpriteFrames", "res://art/characters/zombie_a/zombie_a_frames.tres"),
        "animation": SN("idle"), "autoplay": "idle",
    })
    sc.node("StatusIcon", "Sprite2D", ".", {"position": V2(0, -54), "texture": sc.ext_res("Texture2D", "res://art/fx/icon_suspicious.png")})
    sc.node("Vision", "Node2D", ".", {"position": V2(4, -38), "script": sc.ext_res("Script", "res://scripts/components/vision_component.gd")})
    sc.node("HearingComponent", "Node", ".", {"script": sc.ext_res("Script", "res://scripts/components/hearing_component.gd")})
    sc.node("GroundNavComponent", "Node", ".", {"script": sc.ext_res("Script", "res://scripts/components/ground_nav_component.gd")})
    sc.node("PatrolComponent", "Node", ".", {"script": sc.ext_res("Script", "res://scripts/components/patrol_component.gd")})
    sc.node("AttackComponent", "Node", ".", {"script": sc.ext_res("Script", "res://scripts/components/attack_component.gd")})
    sc.node("StateMachine", "Node", ".", {"script": sc.ext_res("Script", "res://scripts/ai/state_machine.gd"), "initial_state": SN("Idle")})
    for s in STATES:
        f = FILES.get(s, s.lower())
        sc.node(s, "Node", "StateMachine", {"script": sc.ext_res("Script", f"res://scripts/ai/states/{f}.gd")})
    sc.node("Voice", "AudioStreamPlayer2D", ".", {"position": V2(0, -36), "max_distance": 700.0, "attenuation": 1.4, "bus": SN("World")})
    sc.save("scenes/enemies/zombie.tscn")


if __name__ == "__main__":
    build_zombie()
    print("actors ok")
