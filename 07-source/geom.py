"""Production geometry for the Apsira symbol: true filled shapes with real knockouts."""
import math
from shapely.geometry import LineString, Polygon, Point, MultiPolygon, GeometryCollection
from shapely.ops import unary_union
from shapely import affinity

# ---------------- base construction (unit square 0..100) ----------------
RE, RM = 20.0, 14.0
TILT = -18.0


def construction():
    E = (28.0, 52.0)
    axis = (50.0, -4.0)
    L = math.hypot(*axis)
    u = (axis[0] / L, axis[1] / L)
    d = (RE + RM) / math.cos(math.radians(45))      # orthogonal crossing
    M = (E[0] + u[0] * d, E[1] + u[1] * d)
    sh = 50 - (E[0] - RE + M[0] + RM) / 2
    E, M = (E[0] + sh, E[1]), (M[0] + sh, M[1])
    n = (-u[1], u[0])
    a = math.acos((RE + RM) / d)
    ca, sa = math.cos(a), math.sin(a)
    on = lambda c, r, s, t: (c[0] + r * (s * u[0] * ca + t * n[0] * sa), c[1] + r * (s * u[1] * ca + t * n[1] * sa))
    e1, e2 = on(E, RE, 1, -1), on(E, RE, 1, 1)
    m1, m2 = on(M, RM, -1, 1), on(M, RM, -1, -1)
    X = (E[0] + d * u[0] * RE / (RE + RM), E[1] + d * u[1] * RE / (RE + RM))
    PE = (E[0] - u[0] * RE, E[1] - u[1] * RE)
    PM = (M[0] + u[0] * RM, M[1] + u[1] * RM)
    return dict(E=E, M=M, u=u, e1=e1, e2=e2, m1=m1, m2=m2, X=X, PE=PE, PM=PM)


def _arc(c, r, p, q, increasing, n=240):
    a0 = math.atan2(p[1] - c[1], p[0] - c[0]); a1 = math.atan2(q[1] - c[1], q[0] - c[0])
    if increasing:
        while a1 <= a0: a1 += 2 * math.pi
    else:
        while a1 >= a0: a1 -= 2 * math.pi
    return [(c[0] + r * math.cos(a0 + (a1 - a0) * i / n), c[1] + r * math.sin(a0 + (a1 - a0) * i / n)) for i in range(n + 1)]


def centrelines():
    k = construction()
    out = _arc(k["E"], RE, k["PE"], k["e1"], True) + [k["m1"]] + _arc(k["M"], RM, k["m1"], k["PM"], False)[1:]
    ret = _arc(k["M"], RM, k["PM"], k["m2"], False) + [k["e2"]] + _arc(k["E"], RE, k["e2"], k["PE"], True)[1:]
    return k, LineString(out), LineString(ret)


def gear(c, n, rp, add, phase=0.0, tooth=0.56, flat=0.8):
    pts = []
    step = 2 * math.pi / n
    for k in range(n):
        a0 = phase + k * step
        hw = step * tooth / 2; ht = hw * flat
        for a, r in [(a0 - hw, rp - add), (a0 - ht, rp + add), (a0 + ht, rp + add), (a0 + hw, rp - add)]:
            pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
    return Polygon(pts)


SPECS = {
    "full":   dict(w=11.0, sun=True, planets=True, sun_n=10, pl_n=7, pitch=7.0, add=1.8, outline=2.2, tooth=0.56, flat=0.8),
    "simple": dict(w=13.0, sun=True, planets=False, sun_n=8, pl_n=0, pitch=9.0, add=2.4, outline=2.6, tooth=0.6, flat=0.8),
    "micro":  dict(w=15.0, sun=False, planets=False),
}


def symbol(kind, mono=False):
    """Returns (ink_geom, accent_geom) in a normalised frame (rotated, not yet fitted)."""
    S = SPECS[kind]
    k, out_l, ret_l = centrelines()
    w = S["w"]
    out = out_l.buffer(w / 2, cap_style=2, join_style=1, resolution=48)
    ret = ret_l.buffer(w / 2, cap_style=2, join_style=1, resolution=48)
    ink_parts, acc_parts = [], []
    cut = []
    if S.get("sun"):
        rp = S["pitch"] * S["sun_n"] / (2 * math.pi)
        g = gear(k["X"], S["sun_n"], rp, S["add"], math.pi / 4, S["tooth"], S["flat"])
        cut.append(g.buffer(S["outline"], join_style=1))
        ink_parts.append(g.difference(Point(k["X"]).buffer(max(2.4, rp * 0.28), resolution=48)))
    if S.get("planets"):
        rp = S["pitch"] * S["pl_n"] / (2 * math.pi)
        for c in (k["PE"], k["PM"]):
            g = gear(c, S["pl_n"], rp, S["add"], 0.0, S["tooth"], S["flat"])
            cut.append(g.buffer(S["outline"], join_style=1))
            acc_parts.append(g.difference(Point(c).buffer(max(2.4, rp * 0.28), resolution=48)))
    cutter = unary_union(cut) if cut else None
    if cutter is not None:
        out, ret = out.difference(cutter), ret.difference(cutter)
    if kind == "micro":
        if mono:
            # one colour: show the over-under at the crossing with a clearance cut
            # clearance cut only at the central crossing (not at the apsides)
            near_x = Point(k["X"]).buffer(w * 1.6)
            out = out.difference(ret.buffer(2.6, join_style=1).intersection(near_x))
        else:
            out = out.difference(ret)
    ink_parts.append(out)
    acc_parts.append(ret)
    ink, acc = unary_union(ink_parts), unary_union(acc_parts)
    if mono:
        # close sub-unit slivers where the two paths butt at the apsides
        ink, acc = unary_union([ink, acc]).buffer(0.05, join_style=2).buffer(-0.05, join_style=2), GeometryCollection()
    else:
        # ink runs 0.3 units under the accent where they touch, so no background seam shows through.
        # Clipped to the overall silhouette: the outer contour is unchanged.
        whole = unary_union([ink, acc])
        ink = unary_union([ink, acc.buffer(0.3).intersection(ink.buffer(0.3)).intersection(whole)])
    rot = lambda g: affinity.rotate(g, TILT, origin=(50, 50)) if not g.is_empty else g
    return rot(ink), rot(acc)


# ---------------- SVG path output ----------------
def _ring(coords, tx):
    pts = [tx(x, y) for x, y in coords]
    return "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts[:-1]) + " Z"


def to_path(geom, tx=lambda x, y: (x, y)):
    if geom is None or geom.is_empty:
        return ""
    polys = [geom] if isinstance(geom, Polygon) else [g for g in getattr(geom, "geoms", []) if isinstance(g, Polygon)]
    parts = []
    for p in polys:
        p = p.simplify(0.01, preserve_topology=True)
        parts.append(_ring(p.exterior.coords, tx))
        for r in p.interiors:
            parts.append(_ring(r.coords, tx))
    return " ".join(parts)
