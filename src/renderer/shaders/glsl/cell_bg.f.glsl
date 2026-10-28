#include "common.glsl"

// Position the origin to the upper left
layout(origin_upper_left) in vec4 gl_FragCoord;

// Must declare this output for some versions of OpenGL.
layout(location = 0) out vec4 out_FragColor;

layout(binding = 1, std430) readonly buffer bg_cells {
    uint cells[];
};

layout(binding = 2, std430) readonly buffer row_offsets_buf {
    uint row_offsets[];
};

vec4 cell_bg() {
    uvec2 grid_size = unpack2u16(grid_size_packed_2u16);
    vec2 local_pos = gl_FragCoord.xy - grid_padding.wx;
    int grid_x = int(floor(local_pos.x / cell_size.x));
    bool use_linear_blending = (bools & USE_LINEAR_BLENDING) != 0;
    bool has_prompt_padding = (bools & HAS_PROMPT_PADDING) != 0;

    vec4 bg = vec4(0.0);

    // Clamp x position, extends edge bg colors in to padding on sides.
    if (grid_x < 0) {
        if ((padding_extend & EXTEND_LEFT) != 0) {
            grid_x = 0;
        } else {
            return bg;
        }
    } else if (grid_x > int(grid_size.x) - 1) {
        if ((padding_extend & EXTEND_RIGHT) != 0) {
            grid_x = int(grid_size.x) - 1;
        } else {
            return bg;
        }
    }

    int grid_y;
    if (!has_prompt_padding) {
        grid_y = int(floor(local_pos.y / cell_size.y));
        if (grid_y < 0) {
            if ((padding_extend & EXTEND_UP) != 0) {
                grid_y = 0;
            } else {
                return bg;
            }
        } else if (grid_y > int(grid_size.y) - 1) {
            if ((padding_extend & EXTEND_DOWN) != 0) {
                grid_y = int(grid_size.y) - 1;
            } else {
                return bg;
            }
        }
    } else {
        if (local_pos.y < 0.0) {
            if ((padding_extend & EXTEND_UP) != 0) {
                grid_y = 0;
            } else {
                return bg;
            }
        } else {
            int low = 0;
            int high = int(grid_size.y) - 1;
            int candidate = -1;

            while (low <= high) {
                int mid = low + (high - low) / 2;
                float row_top = float(mid) * cell_size.y + float(row_offsets[mid]);
                if (row_top <= local_pos.y) {
                    candidate = mid;
                    low = mid + 1;
                } else {
                    high = mid - 1;
                }
            }

            if (candidate < 0) {
                return bg;
            }

            float cand_top = float(candidate) * cell_size.y + float(row_offsets[candidate]);
            if (local_pos.y < cand_top + cell_size.y) {
                grid_y = candidate;
            } else {
                if (candidate == int(grid_size.y) - 1 && (padding_extend & EXTEND_DOWN) != 0) {
                    grid_y = candidate;
                } else {
                    return bg;
                }
            }
        }
    }

    // Load the color for the cell.
    vec4 cell_color = load_color(
            unpack4u8(cells[grid_y * int(grid_size.x) + grid_x]),
            use_linear_blending
        );

    return cell_color;
}

void main() {
    out_FragColor = cell_bg();
}
