#ifndef HLSL_COLORHELPER
#define HLSL_COLORHELPER

// Convert color from RGB to HSL
// reference : https://www.niwa.nu/2013/05/math-behind-colorspace-conversions-rgb-hsl/
float3 rgbToHsl(float4 color)
{
    float luminance = 0.0f;
    float saturation = 0.0f;
    float hue = 0.0f;

    // find max and min
    float maxvalue = max( max(color.r, color.g), color.b);
    float minvalue = min( min(color.r, color.g), color.b);


    // L
    luminance = 0.5 * (maxvalue + minvalue);
    
    // S 
    if (maxvalue == minvalue) // there's no saturation and the color is a grey
    {
        saturation = 0.0f;
        hue = 0.0f;
    }
    else // calculate S
    {
        if (luminance <= 0.5)
        {
            saturation = (maxvalue-minvalue)/(maxvalue+minvalue);
        }
        else // if luminance > 0.5
        {
            saturation = ( maxvalue-minvalue)/(2.0-maxvalue-minvalue);
        }

        // H
        if (color.r == maxvalue)
        {
            hue = (color.g - color.b ) / (maxvalue - minvalue);
        }
        else if (color.g == maxvalue)
        {
            hue = 2.0 +  (color.b - color.r ) / (maxvalue - minvalue);
        }
        else // b is the max value
        {
            hue = 4.0 + (color.r  - color.g) / (maxvalue - minvalue);
        }

      
        hue *= 60.0; //degrees from 0 to 360 on color wheel
        if (hue < 0)
        {
            hue += 360.0;
        }
    }

    return make_float3(hue, saturation, luminance);
    
   
}


float3 hslToRgb(float3 hsl) {
    float hue = hsl.x;
    float saturation = hsl.y;
    float luminance = hsl.z;
    
    float c = (1.0f - abs(2.0f * luminance - 1.0f)) * saturation;
    float x = c * (1.0f - abs(fmod(hue / 60.0f, 2.0f) - 1.0f));
    float m = luminance - 0.5f * c;
    
    float3 rgb = 0.0f;
    
    if (hue < 60.0f) {
        rgb = make_float3(c, x, 0.0f);
    } else if (hue < 120.0f) {
        rgb = make_float3(x, c, 0.0f);
    } else if (hue < 180.0f) {
        rgb = make_float3(0.0f, c, x);
    } else if (hue < 240.0f) {
        rgb = make_float3(0.0f, x, c);
    } else if (hue < 300.0f) {
        rgb = make_float3(x, 0.0f, c);
    } else {
        rgb = make_float3(c, 0.0f, x);
    }

    return rgb + make_float3(m, m, m);
}

float3 getAnalogusCW(float3 hsl){
    // returns an analogous color on the right (clockwise) (HSL)
    hsl.x += 36.0f;
    if (hsl.x > 360.0f){
        hsl.x -= 360.0f;
    }
    return hsl;
}

float3 getAnalogusCCW(float3 hsl){
    // returns an analogous color on the right (counterclockwise) (HSL)
    hsl.x -= 36.0;
    if (hsl.x < 0.0f){
        hsl.x += 360.0f;
    }
    return hsl;
}

#endif