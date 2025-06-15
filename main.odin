package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

PanOrbitCamera :: struct {
	target:          rl.Vector3,
	distance:        f32,
	angle_yaw:       f32,
	angle_pitch:     f32,
	distance_min:    f32,
	distance_max:    f32,
	angle_pitch_min: f32,
	angle_pitch_max: f32,
	mouse_speed:     f32,
	zoom_speed:      f32,
	pan_speed:       f32,
}

init_pan_orbit_camera :: proc(target: rl.Vector3, distance: f32) -> PanOrbitCamera {
	pi_2 :: math.PI / 2
	return PanOrbitCamera {
		target = target,
		distance = distance,
		angle_yaw = 45.0,
		angle_pitch = 45.0,
		distance_min = 1.0,
		distance_max = 100.0,
		angle_pitch_min = -pi_2 + 0.01,
		angle_pitch_max = pi_2 - 0.01,
		mouse_speed = 0.005,
		zoom_speed = 2.0,
		pan_speed = 0.001,
	}
}

update_pan_orbit_camera :: proc(camera: ^PanOrbitCamera) -> rl.Camera {
	dt := rl.GetFrameTime()

	mouse_delta := rl.GetMouseDelta()
	// Mouse orbit controls
	if rl.IsMouseButtonDown(.RIGHT) {
		camera.angle_yaw -= mouse_delta.x * camera.mouse_speed
		camera.angle_pitch += mouse_delta.y * camera.mouse_speed
		camera.angle_pitch = math.clamp(
			camera.angle_pitch,
			camera.angle_pitch_min,
			camera.angle_pitch_max,
		)
	}

	cos_y := math.cos(camera.angle_pitch)
	sin_y := math.sin(camera.angle_pitch)
	cos_x := math.cos(camera.angle_yaw)
	sin_x := math.sin(camera.angle_yaw)
	// Mouse pan controls
	if rl.IsMouseButtonDown(.MIDDLE) {
		right := rl.Vector3{-sin_x, cos_x, 0}
		forward := rl.Vector3{cos_y * cos_x, cos_y * sin_x, sin_y}
		up := rl.Vector3 {
			forward.y * right.z - forward.z * right.y,
			forward.z * right.x - forward.x * right.z,
			forward.x * right.y - forward.y * right.x,
		}

		pan_distance := camera.distance * camera.pan_speed
		camera.target.x -= (right.x * mouse_delta.x - up.x * mouse_delta.y) * pan_distance
		camera.target.y -= (right.y * mouse_delta.x - up.y * mouse_delta.y) * pan_distance
		camera.target.z -= (right.z * mouse_delta.x - up.z * mouse_delta.y) * pan_distance
	}

	position := rl.Vector3 {
		camera.target.x + camera.distance * cos_y * cos_x,
		camera.target.y + camera.distance * cos_y * sin_x,
		camera.target.z + camera.distance * sin_y,
	}

	return rl.Camera {
		position = position,
		target = camera.target,
		up = {0.0, 0.0, 1.0},
		projection = .PERSPECTIVE,
		fovy = 45.0,
	}
}

Collision :: struct {
	hit:      bool,
	distance: f32,
	index:    uint,
}

draw_axis :: proc(mat: ^rl.Matrix) {
	origin := rl.Vector3{mat[0, 3], mat[1, 3], mat[2, 3]}
	x_axis := rl.Vector3{mat[0, 0], mat[1, 0], mat[2, 0]}
	y_axis := rl.Vector3{mat[0, 1], mat[1, 1], mat[2, 1]}
	z_axis := rl.Vector3{mat[0, 2], mat[1, 2], mat[2, 2]}
	rl.DrawSphere(origin, 0.1, rl.PINK)
	rl.DrawCylinderEx(origin, origin + x_axis, 0.02, 0.02, 10, rl.RED)
	rl.DrawCylinderEx(origin, origin + y_axis, 0.02, 0.02, 10, rl.GREEN)
	rl.DrawCylinderEx(origin, origin + z_axis, 0.02, 0.02, 10, rl.BLUE)
}

main :: proc() {
	rl.InitWindow(1280, 720, "Alignment")

	po_camera := init_pan_orbit_camera(rl.Vector3(0), 10.0)

	pts: []rl.Vector3 = {
		//
		{0.0, 0.0, -1.0},
		{1.0, 0.0, -1.0},
		{1.0, 1.0, -1.0},
		{0.0, 1.0, -1.0},
		{-1.0, 1.0, -1.0},
		{-1.0, 0.0, -1.0},
		{-1.0, -1.0, -1.0},
		{0.0, -1.0, -1.0},
		{1.0, -1.0, -1.0},
		//
		{0.0, 0.0, 0.0},
		{1.0, 0.0, 0.0},
		{1.0, 1.0, 0.0},
		{0.0, 1.0, 0.0},
		{-1.0, 1.0, 0.0},
		{-1.0, 0.0, 0.0},
		{-1.0, -1.0, 0.0},
		{0.0, -1.0, 0.0},
		{1.0, -1.0, 0.0},
		//
		{0.0, 0.0, 1.0},
		{1.0, 0.0, 1.0},
		{1.0, 1.0, 1.0},
		{0.0, 1.0, 1.0},
		{-1.0, 1.0, 1.0},
		{-1.0, 0.0, 1.0},
		{-1.0, -1.0, 1.0},
		{0.0, -1.0, 1.0},
		{1.0, -1.0, 1.0},
	}

	pt_rad :: 0.05
	selected_idx := -1

	aligned_mat := rl.Matrix(1)
	fmt.println("Mat: %v", aligned_mat)

	rl.SetTargetFPS(60)
	for !rl.WindowShouldClose() {
		mouse_pos := rl.GetMousePosition()
		rl_camera := update_pan_orbit_camera(&po_camera)

		rl.BeginDrawing()
		rl.BeginMode3D(rl_camera)

		rl.ClearBackground(rl.Color{24, 24, 24, 255})
		rl.DrawLine3D(rl.Vector3(0), {1.0, 0.0, 0.0}, rl.RED)
		rl.DrawLine3D(rl.Vector3(0), {0.0, 1.0, 0.0}, rl.GREEN)
		rl.DrawLine3D(rl.Vector3(0), {0.0, 0.0, 1.0}, rl.BLUE)

		if rl.IsMouseButtonDown(.LEFT) {
			mouse_ray := rl.GetScreenToWorldRay(mouse_pos, rl_camera)
			found_collision := false
			selected_distance := max(f32)
			for pt, i in pts {
				ray_collision := rl.GetRayCollisionSphere(mouse_ray, pt, pt_rad)
				if ray_collision.hit && ray_collision.distance < selected_distance {
					selected_idx = i
					selected_distance = ray_collision.distance
					found_collision = true
				}
			}

			if !found_collision {
				selected_idx = -1
			}
		}

		if selected_idx >= 0 && rl.IsKeyDown(.O) {
			pt := &pts[selected_idx]
			aligned_mat[0, 3] = pt.x
			aligned_mat[1, 3] = pt.y
			aligned_mat[2, 3] = pt.z
		}

		for pt, i in pts {
			if selected_idx != i {
				rl.DrawSphere(pt, pt_rad, rl.WHITE)
			} else {
				rl.DrawSphere(pt, pt_rad, rl.YELLOW)
			}
		}

        draw_axis(&aligned_mat)


		rl.EndMode3D()
		rl.DrawText(rl.TextFormat("SELECTED: %d", selected_idx), 10, 10, 20, rl.RED)
		rl.EndDrawing()
	}
}
