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

const float4 cMarines = float4(0.923, 0, 0.886, 0) * 2;
const float4 cMarinesStructures = float4(0, 0.125, 0.925, 0) * 4;
const float4 cAliens = float4(1, 1, 0, 0) * 2;
const float4 cAliensGorges = float4(0, 1, 0, 0) * 2.9;
const float4 cAliensStructures = float4(0.992, 0.152, 0.031, 0);
const float4 edgeColorBorder = float4(0.1, 0.1, 0.1, 0) * 0.005;

const float4 whiteFogColor = float4(1, 1, 1, 0);
const float4 orangeFogColor = float4(1, 0.2, 0, 0);
const float4 redFogColor = float4(0.2, 0, 0, 0);
const float4 blackFogColor = float4(0.01, 0, 0, 0);

const float transitionDistanceOrange = 15;
const float transitionDistanceRed = 25;
const float transitionDistanceBlack = 50;

const float offset = 0.0005;

float4 SFXDarkVisionPS(PS_INPUT input) : COLOR0 {
    const float4 inputPixel = tex2D(baseTexture, input.texCoord);

    // disabled while off
    if (amount == 0) {
        return inputPixel;
    }

    const float model = tex2D(depthTexture, input.texCoord).g;
    const float x = (input.texCoord.x - 0.5) * 2;
    const float y = (input.texCoord.y - 0.5) * 2;
    const float distanceSq = x * x + y * y;

    const float2 depth1 = tex2D(depthTexture, input.texCoord).rg;
    const float  depth2 = tex2D(depthTexture, input.texCoord + float2( offset, 0)).rg;
    const float  depth3 = tex2D(depthTexture, input.texCoord + float2(-offset, 0)).rg;
    const float  depth4 = tex2D(depthTexture, input.texCoord + float2( 0,  offset)).rg;
    const float  depth5 = tex2D(depthTexture, input.texCoord + float2( 0, -offset)).rg;

    const float3 worldPosition = float3(input.texCoord.x, input.texCoord.y, tex2D(depthTexture, input.texCoord).r);
    const float distance3D = length(worldPosition);
    const float edgecalc = abs(depth2.r - depth1.r) + abs(depth3.r - depth1.r) + abs(depth4.r - depth1.r) + abs(depth5.r - depth1.r);

    float edge = clamp(edgecalc, depth1.r*0.001, 4);
    float4 edgeColor = float4(0.1, 0.1, 0.1, 0);

    // color of objects
    if (model > 0.5) {

        // marines 1
        if (model > 0.99) {
            edge = clamp(edgecalc*20, 0.08, 2);
            return lerp(inputPixel, cMarines * edge, amount * (0.1 + edge) * 0.5);
        }

        edge = clamp(edgecalc*2, 0.08, 2);

        // marine structures 0.98
        if (model > 0.97) {
            return lerp(inputPixel, cMarinesStructures * edge, amount * (0.1 + edge) * 0.5);
        }

        // alien players 0.96
        if (model > 0.95) {
            return lerp(inputPixel, cAliens * edge, amount * (0.1 + edge) * 0.5);
        }

        // gorges 0.94
        if (model > 0.93) {
            return lerp(inputPixel, cAliensGorges * edge, amount * (0.1 + edge) * 0.5);
        }

        // alien structures 0.9
        return lerp(inputPixel, cAliensStructures * edge, amount * (1 + edge) * 0.5);
    }

    // smoothstep functions for smoother transitions
    const float smoothstepOrange = smoothstep(0.0, 1.0, saturate((distance3D - 1.0) / transitionDistanceOrange));
    const float smoothstepRed = smoothstep(0.0, 1.0, saturate((distance3D - transitionDistanceOrange) / (transitionDistanceRed - transitionDistanceOrange)));
    const float smoothstepBlack = smoothstep(0.0, 1.0, saturate((distance3D - transitionDistanceRed) / (transitionDistanceBlack - transitionDistanceRed)));

    float4 fogColor = float4(1, 1, 1, 0) * 2;
    fogColor *= lerp(lerp(lerp(whiteFogColor, orangeFogColor, smoothstepOrange), redFogColor, smoothstepRed), blackFogColor, smoothstepBlack);
    const float4 fog = clamp(pow(depth1.r * 1, 0), 0, 1) * fogColor;

    // color of environment
    return lerp(inputPixel*0.1, max(inputPixel, edge * edgeColor * 0.2) + fog * edge, 0.1);
}
