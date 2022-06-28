#include <renderer/RenderSetup.hlsl>

struct VS_INPUT {
    float3 ssPosition : POSITION;
    float2 texCoord : TEXCOORD0;
    float4 color : COLOR0;
};

struct VS_OUTPUT {
    float2 texCoord : TEXCOORD0;
    float4 color : COLOR0;
    float4 ssPosition : SV_POSITION;
};

struct PS_INPUT {
    float2 texCoord : TEXCOORD0;
    float4 color : COLOR0;
};

sampler2D baseTexture;
sampler2D depthTexture;
sampler2D normalTexture;

cbuffer LayerConstants {
    float startTime;
    float amount;
};

// Vertex shader
VS_OUTPUT SFXBasicVS(VS_INPUT input) {
    VS_OUTPUT output;
    output.ssPosition = float4(input.ssPosition, 1);
    output.texCoord = input.texCoord + texelCenter;
    output.color = input.color;

    return output;
}

const float4 cBorder = float4(0.1, 0.1, 0.1, 0) * 0.005;
const float4 cMarines = float4(0.923, 0, 0.886, 0) * 2;
const float4 cMarinesStructures = float4(0, 0.125, 0.925, 0) * 4;
const float4 cAliens = float4(1, 1, 0, 0) * 2;
const float4 cAliensGorges = float4(0, 1, 0, 0) * 2.9;
const float4 cAliensStructures = float4(0.992, 0.152, 0.031, 0);
const float4 edgeColorBorder = float4(0.1, 0.1, 0.1, 0) * 0.005;

float4 SFXDarkVisionPS(PS_INPUT input) : COLOR0 {
    float2 texCoord = input.texCoord;
    float4 inputPixel = tex2D(baseTexture, texCoord);
    float depth = tex2D(depthTexture, texCoord).r;
    float model = tex2D(depthTexture, texCoord).g;
    float3 normal = tex2D(normalTexture, texCoord).xyz;

    // disabled while off
    if (amount == 0) {
        return inputPixel;
    }

    float x = (texCoord.x - .5) * 2;
    float y = (texCoord.y - .5) * 2;
    float distanceSq = x * x + y * y;

    float2 depth1 = tex2D(depthTexture, input.texCoord).rg;

    float fadeout = min(1, pow(2.0, 0.5 - depth1.r * .4));

    // makes edge lines
    float offset = 0.0002 + model * distanceSq * 0;
    float edgecalc = abs(tex2D(depthTexture, saturate(texCoord + float2(offset, 0))).r - depth) + abs(tex2D(depthTexture, saturate(texCoord + float2(-offset, 0))).r - depth) + abs(tex2D(depthTexture, saturate(texCoord + float2(0, offset))).r - depth) + abs(tex2D(depthTexture, saturate(texCoord + float2(0, -offset))).r - depth);
    float edge = clamp(edgecalc, 0.1, 1);

    float fogColor = float4(.4, .4, .4, 0);
    float4 fog = clamp(pow(depth * .006, 1), 0, 2.0) * fogColor;

    float4 baseColor;
    float4 edgeColor;
    float mixfactor1 = .99;
    float mixfactor2 = .94;

    if (model > 0.5) {
        // color of objects
        if (model > 0.99) {
            // marines 1
            return lerp(inputPixel, cMarines * edge, amount * (0.1 + edge) * 0.5);
        } else if (model > 0.97) {
            // marine structures 0.98
            return lerp(inputPixel, cMarinesStructures * edge, amount * (0.1 + edge) * 0.5);
        } else if (model > 0.95) {
            // alien players 0.96
            return lerp(inputPixel, cAliens * edge, amount * (0.1 + edge) * 0.5);
        } else if (model > 0.93) {
            // gorges 0.94
            return lerp(inputPixel, cAliensGorges * edge, amount * (0.1 + edge) * 0.5);
        } else {
            // alien structures 0.9
            return lerp(inputPixel, cAliensStructures * edge, amount * (1 + edge) * 0.5);
        }
        baseColor = float4(.02, .01, .01, 0);
        edgeColor = float4(.17, .15, .15, 0);
        edge = clamp(edgecalc, 0, 1);

        return lerp(inputPixel, max(inputPixel * baseColor, edge * edgeColor) - fog * edge, mixfactor2);
    } else {
        // color of environment
        baseColor = float4(.02, .01, .01, 0);
        edgeColor = float4(.17, .15, .15, 0);
        edge = clamp(edgecalc, 0, 1);

        return lerp(inputPixel, max(inputPixel * baseColor, edge * edgeColor) - fog * edge, mixfactor2);
    }

    return inputPixel;
}
