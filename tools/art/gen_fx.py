"""Small effect sprites."""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from pixlib import Canvas, c, make_sheet  # noqa: E402


def glint():
    frames = []
    for size in (1, 2, 3):
        cv = Canvas(7, 7)
        col = c("white", 2)
        for k in range(size + 1):
            cv.px(3 + k, 3, col if k < size else c("warm", 5))
            cv.px(3 - k, 3, col if k < size else c("warm", 5))
            cv.px(3, 3 + k, col if k < size else c("warm", 5))
            cv.px(3, 3 - k, col if k < size else c("warm", 5))
        frames.append(cv)
    make_sheet(frames).save("fx/glint.png")


def muzzle():
    cv = Canvas(10, 7)
    cv.poly([(0, 2), (6, 0), (9, 3), (6, 6), (0, 4)], c("warm", 5))
    cv.rect(0, 2, 5, 3, c("white", 2))
    cv.px(8, 3, c("warm", 6))
    cv.save("fx/muzzle.png")


def dust():
    cv = Canvas(2, 2)
    cv.px(0, 0, c("paper", 5))
    cv.save("fx/dust.png")
    cv = Canvas(1, 1)
    cv.px(0, 0, c("white", 2))
    cv.save("fx/pixel.png")


def blood():
    frames = []
    for r in (1, 2, 3, 2):
        cv = Canvas(9, 9)
        for k in range(r * 3):
            cv.px(4 + (k % 3) - 1 + (k // 3) * (1 if k % 2 else -1), 4 + (k % 2) * (1 if k % 4 else -1), c("blood", 3))
        frames.append(cv)
    make_sheet(frames).save("fx/blood.png")


def sparks():
    cv = Canvas(3, 3)
    cv.px(1, 1, c("warm", 6))
    cv.px(0, 1, c("warm", 4))
    cv.save("fx/spark.png")


if __name__ == "__main__":
    glint()
    muzzle()
    dust()
    blood()
    sparks()
    print("fx ok")


def status_icons():
    q = ["XXX.", "...X", "..X.", ".X..", "....", ".X.."]
    e = [".X", ".X", ".X", ".X", "..", ".X"]
    for name, tpl, col in [("icon_suspicious", q, c("yellow", 5)), ("icon_alert", e, c("red", 5))]:
        cv = Canvas(6, 8)
        for y, r in enumerate(tpl):
            for x, ch in enumerate(r):
                if ch == "X":
                    cv.px(x + 1, y + 1, col)
        cv.outline(c("ink", 0))
        cv.save(f"fx/{name}.png")


if __name__ == "__main__":
    status_icons()
