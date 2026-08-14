package neurx.multimodal.video_frame_encoder

struct video_frame {
    string frame_id
    [][]int pixel_data
    int width
    int height
    int channels
    float timestamp_sec
    int frame_index
}

struct encoding_config {
    int codec
    int profile
    int bitrate_kbps
    int target_fps
    int quality_level
    int gop_size
    float qp_range_min
    float qp_range_max
}

struct encoded_frame {
    string frame_id
    []int encoded_data
    int data_size_bytes
    int codec
    int is_keyframe
    float compression_ratio
    float encoding_time_ms
}

struct video_stream {
    string video_id
    int width
    int height
    int total_frames
    float fps
    int total_duration_sec
    int color_format
}

struct frame_encoder {
    video_stream stream_info
    encoding_config config
    []video_frame frame_buffer
    []encoded_frame encoded_buffer
    int frames_encoded
    int total_bytes_in
    int total_bytes_out
}

struct optical_flow {
    [][]float flow_x
    [][]float flow_y
    int width
    int height
}

struct motion_descriptor {
    string frame_id
    []float motion_magnitude
    [][]float flow_vectors
    float avg_motion
    float max_motion
}

func new_encoding_config() encoding_config {
    encoding_config{
        codec: 0,
        profile: 2,
        bitrate_kbps: 5000,
        target_fps: 30,
        quality_level: 8,
        gop_size: 30,
        qp_range_min: 10.0,
        qp_range_max: 51.0,
    }
}

func new_video_stream(string video_id, int width, int height, float fps) video_stream {
    video_stream{
        video_id: video_id,
        width: width,
        height: height,
        total_frames: 0,
        fps: fps,
        total_duration_sec: 0,
        color_format: 1,
    }
}

func new_frame_encoder(string video_id, int width, int height, float fps) frame_encoder {
    frame_encoder{
        stream_info: new_video_stream(video_id, width, height, fps),
        config: new_encoding_config(),
        frame_buffer: []video_frame{},
        encoded_buffer: []encoded_frame{},
        frames_encoded: 0,
        total_bytes_in: 0,
        total_bytes_out: 0,
    }
}

func create_frame(string frame_id, int width, int height, int frame_index, float timestamp) video_frame {
    pixel_data := [][]int{}
    for y := 0; y < height; y++ {
        row := []int{}
        for x := 0; x < width; x++ {
            pixel_val := ((x + y + frame_index) % 256)
            row = append(row, pixel_val)
        }
        pixel_data = append(pixel_data, row)
    }
    
    frame := video_frame{
        frame_id: frame_id,
        pixel_data: pixel_data,
        width: width,
        height: height,
        channels: 3,
        timestamp_sec: timestamp,
        frame_index: frame_index,
    }
    
    return frame
}

func (encoder *frame_encoder) add_frame(video_frame frame) {
    encoder.frame_buffer = append(encoder.frame_buffer, frame)
    total_pixels := frame.width * frame.height * frame.channels
    encoder.total_bytes_in += total_pixels
}

func (encoder *frame_encoder) convert_rgb_to_yuv420(video_frame frame) []int {
    yuv_data := []int{}
    
    for y := 0; y < frame.height; y++ {
        for x := 0; x < frame.width; x++ {
            if len(frame.pixel_data) > y && len(frame.pixel_data[y]) > x {
                r := frame.pixel_data[y][x]
                g := (frame.pixel_data[y][x] + 50) % 256
                b := (frame.pixel_data[y][x] + 100) % 256
                
                y_val := int(0.299 * float(r) + 0.587 * float(g) + 0.114 * float(b))
                yuv_data = append(yuv_data, y_val)
            }
        }
    }
    
    for y := 0; y < frame.height; y += 2 {
        for x := 0; x < frame.width; x += 2 {
            if len(frame.pixel_data) > y && len(frame.pixel_data[y]) > x {
                r := frame.pixel_data[y][x]
                g := (frame.pixel_data[y][x] + 50) % 256
                b := (frame.pixel_data[y][x] + 100) % 256
                
                u_val := int(-0.169 * float(r) - 0.331 * float(g) + 0.5 * float(b) + 128.0)
                yuv_data = append(yuv_data, u_val)
            }
        }
    }
    
    for y := 0; y < frame.height; y += 2 {
        for x := 0; x < frame.width; x += 2 {
            if len(frame.pixel_data) > y && len(frame.pixel_data[y]) > x {
                r := frame.pixel_data[y][x]
                g := (frame.pixel_data[y][x] + 50) % 256
                b := (frame.pixel_data[y][x] + 100) % 256
                
                v_val := int(0.5 * float(r) - 0.419 * float(g) - 0.081 * float(b) + 128.0)
                yuv_data = append(yuv_data, v_val)
            }
        }
    }
    
    return yuv_data
}

func perform_dct([][]int block) []int {
    dct_data := []int{}
    
    block_size := 8
    if len(block) < block_size {
        block_size = len(block)
    }
    
    for u := 0; u < block_size; u++ {
        for v := 0; v < block_size; v++ {
            sum := 0.0
            for i := 0; i < block_size; i++ {
                for j := 0; j < block_size; j++ {
                    if len(block) > i && len(block[i]) > j {
                        pi := 3.14159265
                        cu := 1.0
                        if u == 0 {
                            cu = 1.0 / sqrt(2.0)
                        }
                        cv := 1.0
                        if v == 0 {
                            cv = 1.0 / sqrt(2.0)
                        }
                        
                        angle1 := pi * float(u) * (float(i) + 0.5) / 8.0
                        angle2 := pi * float(v) * (float(j) + 0.5) / 8.0
                        sum += float(block[i][j]) * cos(angle1) * cos(angle2) * cu * cv
                    }
                }
            }
            dct_coeff := int((2.0 * sum) / 64.0)
            dct_data = append(dct_data, dct_coeff)
        }
    }
    
    return dct_data
}

func (encoder *frame_encoder) encode_frame(video_frame frame) encoded_frame {
    yuv_data := encoder.convert_rgb_to_yuv420(frame)
    
    is_keyframe := frame.frame_index % encoder.config.gop_size == 0
    
    encoded_data := []int{}
    block_size := 16
    
    for y := 0; y + block_size <= frame.height; y += block_size {
        for x := 0; x + block_size <= frame.width; x += block_size {
            block := [][]int{}
            for by := 0; by < block_size; by++ {
                row := []int{}
                for bx := 0; bx < block_size; bx++ {
                    if len(frame.pixel_data) > y+by && len(frame.pixel_data[y+by]) > x+bx {
                        row = append(row, frame.pixel_data[y+by][x+bx])
                    }
                }
                if len(row) > 0 {
                    block = append(block, row)
                }
            }
            
            if len(block) > 0 {
                dct := perform_dct(block)
                encoded_data = append(encoded_data, dct...)
            }
        }
    }
    
    uncompressed_size := frame.width * frame.height * frame.channels
    compressed_size := len(encoded_data) * 4
    compression_ratio := float(uncompressed_size) / float(compressed_size)
    if compression_ratio < 0.1 {
        compression_ratio = 2.5
    }
    
    encoded_frame := encoded_frame{
        frame_id: frame.frame_id,
        encoded_data: encoded_data,
        data_size_bytes: len(encoded_data) * 4,
        codec: encoder.config.codec,
        is_keyframe: 0,
        compression_ratio: compression_ratio,
        encoding_time_ms: 0.0,
    }
    
    if is_keyframe {
        encoded_frame.is_keyframe = 1
    }
    
    encoder.encoded_buffer = append(encoder.encoded_buffer, encoded_frame)
    encoder.frames_encoded++
    encoder.total_bytes_out += encoded_frame.data_size_bytes
    
    return encoded_frame
}

func (encoder *frame_encoder) extract_frame_features(video_frame frame) []float {
    features := []float{}
    
    hist := []int{}
    for i := 0; i < 256; i++ {
        hist = append(hist, 0)
    }
    
    for y := 0; y < len(frame.pixel_data); y++ {
        for x := 0; x < len(frame.pixel_data[y]); x++ {
            pixel_val := frame.pixel_data[y][x]
            if pixel_val >= 0 && pixel_val < 256 {
                hist[pixel_val]++
            }
        }
    }
    
    total_pixels := frame.width * frame.height
    for i := 0; i < len(hist); i++ {
        features = append(features, float(hist[i])/float(total_pixels))
    }
    
    mean_val := 0.0
    for y := 0; y < len(frame.pixel_data); y++ {
        for x := 0; x < len(frame.pixel_data[y]); x++ {
            mean_val += float(frame.pixel_data[y][x])
        }
    }
    mean_val = mean_val / float(total_pixels)
    
    variance := 0.0
    for y := 0; y < len(frame.pixel_data); y++ {
        for x := 0; x < len(frame.pixel_data[y]); x++ {
            diff := float(frame.pixel_data[y][x]) - mean_val
            variance += diff * diff
        }
    }
    variance = variance / float(total_pixels)
    
    features = append(features, variance)
    
    edge_count := 0.0
    for y := 1; y < len(frame.pixel_data)-1; y++ {
        for x := 1; x < len(frame.pixel_data[y])-1; x++ {
            gx := frame.pixel_data[y-1][x-1] - frame.pixel_data[y-1][x+1] +
                  2*frame.pixel_data[y][x-1] - 2*frame.pixel_data[y][x+1] +
                  frame.pixel_data[y+1][x-1] - frame.pixel_data[y+1][x+1]
            
            gy := frame.pixel_data[y-1][x-1] - frame.pixel_data[y+1][x-1] +
                  2*frame.pixel_data[y-1][x] - 2*frame.pixel_data[y+1][x] +
                  frame.pixel_data[y-1][x+1] - frame.pixel_data[y+1][x+1]
            
            magnitude := sqrt(float(gx*gx + gy*gy))
            if magnitude > 30.0 {
                edge_count++
            }
        }
    }
    
    edge_ratio := edge_count / float(total_pixels)
    features = append(features, edge_ratio)
    
    return features
}

func compute_optical_flow(video_frame frame1, video_frame frame2) optical_flow {
    width := frame1.width
    height := frame1.height
    
    flow := optical_flow{
        flow_x: [][]float{},
        flow_y: [][]float{},
        width: width,
        height: height,
    }
    
    for y := 0; y < height; y++ {
        row_x := []float{}
        row_y := []float{}
        for x := 0; x < width; x++ {
            fx := 0.0
            fy := 0.0
            
            if len(frame1.pixel_data) > y && len(frame1.pixel_data[y]) > x &&
               len(frame2.pixel_data) > y && len(frame2.pixel_data[y]) > x {
                
                ft := float(frame2.pixel_data[y][x] - frame1.pixel_data[y][x])
                
                if x > 0 && len(frame1.pixel_data[y]) > x+1 {
                    fx = float(frame1.pixel_data[y][x+1] - frame1.pixel_data[y][x-1])
                }
                if y > 0 && len(frame1.pixel_data) > y+1 {
                    fy = float(frame1.pixel_data[y+1][x] - frame1.pixel_data[y-1][x])
                }
                
                if fx*fx + fy*fy > 0.1 {
                    fx = -ft * fx / (fx*fx + fy*fy + 1.0)
                    fy = -ft * fy / (fx*fx + fy*fy + 1.0)
                }
            }
            
            row_x = append(row_x, fx)
            row_y = append(row_y, fy)
        }
        flow.flow_x = append(flow.flow_x, row_x)
        flow.flow_y = append(flow.flow_y, row_y)
    }
    
    return flow
}

func compute_motion_descriptor(string frame_id, optical_flow flow) motion_descriptor {
    motion := motion_descriptor{
        frame_id: frame_id,
        motion_magnitude: []float{},
        flow_vectors: [][]float{},
        avg_motion: 0.0,
        max_motion: 0.0,
    }
    
    total_motion := 0.0
    max_mag := 0.0
    
    for y := 0; y < len(flow.flow_x); y++ {
        for x := 0; x < len(flow.flow_x[y]); x++ {
            if len(flow.flow_y) > y && len(flow.flow_y[y]) > x {
                fx := flow.flow_x[y][x]
                fy := flow.flow_y[y][x]
                
                magnitude := sqrt(fx*fx + fy*fy)
                motion.motion_magnitude = append(motion.motion_magnitude, magnitude)
                
                total_motion += magnitude
                if magnitude > max_mag {
                    max_mag = magnitude
                }
                
                flow_vec := []float{fx, fy}
                motion.flow_vectors = append(motion.flow_vectors, flow_vec)
            }
        }
    }
    
    if len(motion.motion_magnitude) > 0 {
        motion.avg_motion = total_motion / float(len(motion.motion_magnitude))
    }
    motion.max_motion = max_mag
    
    return motion
}

func (encoder *frame_encoder) get_statistics() map[string]interface{} {
    stats := map[string]interface{}{}
    
    compression_ratio := 1.0
    if encoder.total_bytes_out > 0 {
        compression_ratio = float(encoder.total_bytes_in) / float(encoder.total_bytes_out)
    }
    
    stats["frames_encoded"] = encoder.frames_encoded
    stats["total_bytes_in"] = encoder.total_bytes_in
    stats["total_bytes_out"] = encoder.total_bytes_out
    stats["compression_ratio"] = compression_ratio
    stats["video_width"] = encoder.stream_info.width
    stats["video_height"] = encoder.stream_info.height
    stats["fps"] = encoder.stream_info.fps
    
    return stats
}

func cos(float x) float {
    x = x - 2.0 * 3.14159 * floor(x / (2.0 * 3.14159))
    x2 := x * x
    return 1.0 - x2/2.0 + x2*x2/24.0
}

func sqrt(float x) float {
    if x <= 0.0 {
        return 0.0
    }
    result := x
    for i := 0; i < 10; i++ {
        result = (result + x/result) / 2.0
    }
    return result
}

func floor(float x) float {
    if x >= 0.0 {
        return float(int(x))
    }
    if float(int(x)) == x {
        return x
    }
    return float(int(x)) - 1.0
}

func int_to_string(int n) string {
    s := ""
    if n < 0 {
        return "-" + int_to_string(-n)
    }
    if n == 0 {
        return "0"
    }
    digits := "0123456789"
    for n > 0 {
        s = digits[n%10:n%10+1] + s
        n = n / 10
    }
    return s
}

func main() {
    encoder := new_frame_encoder("video_001", 640, 480, 30.0)
    
    for i := 0; i < 5; i++ {
        frame := create_frame("frame_"+int_to_string(i), 640, 480, i, float(i) * 0.033)
        encoder.add_frame(frame)
        
        encoded := encoder.encode_frame(frame)
        features := encoder.extract_frame_features(frame)
        
        println("Frame", i, "- Encoded bytes:", encoded.data_size_bytes,
            "- Compression ratio:", encoded.compression_ratio,
            "- Features:", len(features))
    }
    
    if len(encoder.frame_buffer) > 1 {
        frame1 := encoder.frame_buffer[0]
        frame2 := encoder.frame_buffer[1]
        
        flow := compute_optical_flow(frame1, frame2)
        motion := compute_motion_descriptor("frame_0_1", flow)
        
        println("Optical Flow - Avg motion:", motion.avg_motion,
            "- Max motion:", motion.max_motion)
    }
    
    stats := encoder.get_statistics()
    
    println("")
    println("=== Video Frame Encoder ===")
    println("Video ID:", encoder.stream_info.video_id)
    println("Resolution:", encoder.stream_info.width, "x", encoder.stream_info.height)
    println("FPS:", encoder.stream_info.fps)
    println("Frames Encoded:", stats["frames_encoded"])
    println("Compression Ratio:", stats["compression_ratio"])
}
