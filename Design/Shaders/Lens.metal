//
//  Lens.metal
//  Windfall
//
//  How the sidebar's lens bends what lies beneath it.
//
//  This file is not Swift. It is written in Metal, the language for small
//  programs that run on the graphics chip. This one runs once for every
//  dot on the screen under the sidebar's rows, many times a second, which
//  is why it has to be this kind of program: Swift would be far too slow.
//
//  For each dot it answers one question: "which part of the picture
//  should be shown here?" Outside the lens the answer is "the part that
//  was here already". Inside, it is a part a little nearer the middle,
//  which magnifies. Near the rim it is a part from beyond the edge, which
//  squeezes the surroundings into view the way thick glass does. The
//  red, green and blue are fetched from very slightly different places,
//  which gives the faint coloured fringe real glass has.
//
//  SwiftUI calls it from LensRefraction in MainTabView.swift.
//
//  WAITING: this file is kept in Design/Shaders, outside the app, until
//  Xcode's "Metal Toolchain" is installed. Xcode cannot build a .metal
//  file without it, and would refuse to build the whole app. To switch
//  the effect on, see `isBuilt` in LensRefraction.
//

#include <SwiftUI/SwiftUI_Metal.h>
#include <metal_stdlib>
using namespace metal;

// How far a point is from the edge of a rounded rectangle whose middle
// is at 0, 0. Below zero means inside it, above zero means outside.
static float roundedBoxDistance(float2 point, float2 halfSize, float radius) {
    float2 q = abs(point) - halfSize + radius;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

// position   the dot being drawn
// layer      the picture of the sidebar's rows
// centre     the middle of the lens
// halfSize   half its width and half its height
// radius     how round its corners are
// strength   0 for flat glass (no bending), 1 for the full effect
[[ stitchable ]] half4 lensRefraction(float2 position, SwiftUI::Layer layer,
                                      float2 centre, float2 halfSize,
                                      float radius, float strength) {
    float2 fromCentre = position - centre;
    float distance = roundedBoxDistance(fromCentre, halfSize, radius);

    // Outside the lens, or with the effect off: leave the picture alone.
    if (distance >= 0.0 || strength <= 0.001) {
        return layer.sample(position);
    }

    // Which way is "out of the lens" from here. Found by asking how the
    // distance to the edge changes a short step to the right and down.
    float2 step = float2(0.75, 0.0);
    float2 outward = float2(
        roundedBoxDistance(fromCentre + step.xy, halfSize, radius) - roundedBoxDistance(fromCentre - step.xy, halfSize, radius),
        roundedBoxDistance(fromCentre + step.yx, halfSize, radius) - roundedBoxDistance(fromCentre - step.yx, halfSize, radius));
    float size = length(outward);
    outward = size > 0.0001 ? outward / size : float2(0.0, 0.0);

    // 1 at the rim of the lens, fading to 0 a little way in.
    float rimWidth = 14.0;
    float rim = 1.0 - clamp(-distance / rimWidth, 0.0, 1.0);
    rim = rim * rim * rim;

    // The middle magnifies a little: look slightly nearer the centre.
    float2 source = position - fromCentre * (0.07 * strength);
    // The rim is steep glass: look outwards, past the lens's own edge.
    source += outward * rim * 16.0 * strength;

    // Fetch the three colours from slightly different places at the rim.
    float2 fringe = outward * rim * 3.0 * strength;
    half4 red = layer.sample(source + fringe);
    half4 green = layer.sample(source);
    half4 blue = layer.sample(source - fringe);
    return half4(red.r, green.g, blue.b, max(green.a, max(red.a, blue.a)));
}
