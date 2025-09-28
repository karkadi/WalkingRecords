#include <metal_stdlib>
using namespace metal;

float2 rotate(float2 inVec, float alpha) {
    return float2(
        inVec.x * cos(alpha) + inVec.y * sin(alpha),
        inVec.y * cos(alpha) - inVec.x * sin(alpha)
    );
}

float body(float2 uv, float2 leftLeg, float2 rightLeg, float2 center) {
    float baseRadius = 0.18;
    float2 leftLeg2 = leftLeg - center;
    float2 rightLeg2 = rightLeg - center;
    float leftRadius = length(leftLeg2);
    float rightRadius = length(rightLeg2);
    float2 leftDir = leftLeg2 / leftRadius;
    float2 rightDir = rightLeg2 / rightRadius;
    float2 r = uv - center;
    float lenUV = length(r);
    
    float2 uvDir = r / lenUV;
    float leftDist = length(uvDir - leftDir);
    float rightDist = length(uvDir - rightDir);
    float leftFactor = pow(max(1.0 - leftDist, 0.0), 3.0);
    float rightFactor = pow(max(1.0 - rightDist, 0.0), 3.0);
    float centerFactor = 1.0 - leftFactor - rightFactor;
    
    float radius = leftFactor * leftRadius + rightFactor * rightRadius + centerFactor * baseRadius;
    if (lenUV < radius) {
        return 0.0;
    }
    return 1.0;
}

float2 getLegCenter(float angle) {
    float2 leftLegCenter = float2(
        sin(angle),
        max(cos(angle), 0.0)
    );
    leftLegCenter = float2(0.4, 0.2) * leftLegCenter + float2(0.0, -0.6);
    return leftLegCenter;
}

float leg(float2 uv, float2 legCenter) {
    float angle = (legCenter.y + 0.6) * 1.5;
    float2 diff = uv - legCenter;
    diff = rotate(diff, angle);
    diff.y *= 1.6;
    if (diff.y < 0.0) {
        diff.y *= 5.2;
    }
    
    if (length(diff) < 0.2) {
        return 0.0;
    }
    return 1.0;
}

float head(float2 diff) {
    float2 diff2 = rotate(diff, -0.4);
    diff2 = diff2 * float2(5.0, 7.0);
    if (length(diff2) < 1.0) {
        return 0.0;
    }
    return 1.0;
}

float walker(float2 uv, float iTime) {
    float val = 1.0;
    
    if (uv.y < -0.6) {
        val = 0.0;
    }
    
    float progress = 6.66 * iTime;
    
    float2 leftLegCenter = getLegCenter(progress);
    float2 rightLegCenter = getLegCenter(progress + 3.141592);
    
    float2 achillesOffset = float2(-0.15, 0.0);
    
    float2 bodyCenter = float2(0.0, -0.05 + 0.1 * sin(progress * 2.0));
    float2 headCenter = bodyCenter + float2(0.10 + 0.08 * cos(progress * 2.0 + 0.3), 0.23);
    
    val *= leg(uv, leftLegCenter) * leg(uv, rightLegCenter);
    val *= body(uv, leftLegCenter + achillesOffset, rightLegCenter + achillesOffset, bodyCenter);
    val *= head(uv - headCenter);
    return val;
}

[[stitchable]] half4 walking(float2 position, half4 inColor, float4 bounds, float iTime) {
    // Normalize coordinates
    float2 resolution = float2(bounds.z, bounds.w);
    float2 uv = position / resolution - float2(0.5, 0.5);
    uv.x *= resolution.x / resolution.y;
    uv.y *= -1;
    uv *= 1.5;
    
    float walkerVal = walker(uv, iTime);
    float val = abs(walkerVal - walker(uv - float2(0.0, 0.01), iTime));
    val += abs(walkerVal - walker(uv - float2(0.01, 0.0), iTime));
    
    if (bounds.x > 0.5) {
        val = 1.0 - val;
    }
    
    return half4(val * half3(1.0, 1.0, 1.0), 1.0);
}
