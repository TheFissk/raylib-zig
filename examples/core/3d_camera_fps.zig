//!*******************************************************************************************
//!
//!   raylib-zig port of the [core] example - 3d camera fps
//!
//!   Example complexity rating: [★★★☆] 3/4
//!
//!   Example originally created with raylib 5.5, last time updated with raylib 5.5
//!
//!   Example contributed by Agnis Aldiņš (@nezvers) and reviewed by Ramon Santamaria (@raysan5)
//!   Translated to raylib-zig by Timothy Fiss (@TheFissk)
//!
//!   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
//!   BSD-like license that allows static linking with closed source software
//!
//!   Copyright (c) 2025 Agnis Aldiņš (@nezvers)
//!
//!*******************************************************************************************

const rl = @import("raylib");
const std = @import("std");

//----------------------------------------------------------------------------------
// Defines and Macros
//----------------------------------------------------------------------------------
// Movement constants
const GRAVITY: comptime_float = 32.0;
const MAX_SPEED: comptime_float = 20.0;
const CROUCH_SPEED: comptime_float = 5.0;
const JUMP_FORCE: comptime_float = 12.0;
const MAX_ACCEL: comptime_float = 150.0;
// Grounded drag
const FRICTION: comptime_float = 0.86;
// Increasing air drag, increases strafing speed
const AIR_DRAG: comptime_float = 0.98;
// Responsiveness for turning movement direction to looked direction
const CONTROL: comptime_float = 15.0;
const CROUCH_HEIGHT: comptime_float = 0.0;
const STAND_HEIGHT: comptime_float = 1.0;
const BOTTOM_HEIGHT: comptime_float = 0.5;

const NORMALIZE_INPUT: bool = false;

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------
// Body structure
const Body = struct {
    position: rl.Vector3,
    velocity: rl.Vector3,
    dir: rl.Vector3,
    isGrounded: bool,
};

//----------------------------------------------------------------------------------
// Global Variables Definition
//----------------------------------------------------------------------------------
var sensitivity: rl.Vector2 = .{ .x = 0.001, .y = 0.001 };

var player: Body = .{
    .position = .{ .x = 0, .y = 0, .z = 0 },
    .velocity = .{ .x = 0, .y = 0, .z = 0 },
    .dir = .{ .x = 0, .y = 0, .z = 0 },
    .isGrounded = false,
};
var lookRotation: rl.Vector2 = .{ .x = 0, .y = 0 };
var headTimer: f32 = 0.0;
var walkLerp: f32 = 0.0;
var headLerp: f32 = STAND_HEIGHT;
var lean: rl.Vector2 = .{ .x = 0, .y = 0 };

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib [core] example - 3d camera fps");
    defer rl.closeWindow();

    // Initialize camera variables
    var camera: rl.Camera = .{
        .fovy = 60,
        .projection = .perspective,
        .position = .{
            .x = player.position.x,
            .y = player.position.y + (BOTTOM_HEIGHT + headLerp),
            .z = player.position.z,
        },
        .up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .target = rl.Vector3{ .x = 0.0, .y = 0.0, .z = -1.0 },
    };

    UpdateCameraFPS(&camera); // Update camera parameters

    rl.disableCursor(); // Limit cursor to relative movement inside the window

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------
        const mouseDelta = rl.getMouseDelta();
        lookRotation.x -= mouseDelta.x * sensitivity.x;
        lookRotation.y += mouseDelta.y * sensitivity.y;

        const sideway: f32 = @floatFromInt(@as(i32, @intFromBool(rl.isKeyDown(.d))) - @as(i32, @intFromBool(rl.isKeyDown(.a))));
        const forward: f32 = @floatFromInt(@as(i32, @intFromBool(rl.isKeyDown(.w))) - @as(i32, @intFromBool(rl.isKeyDown(.s))));
        const crouching: bool = rl.isKeyDown(.left_control);
        const jump_pressed: bool = rl.isKeyPressed(.space);
        updateBody(&player, lookRotation.x, sideway, forward, jump_pressed, crouching);

        const delta: f32 = rl.getFrameTime();
        const height: f32 = if (crouching) CROUCH_HEIGHT else STAND_HEIGHT;
        headLerp = rl.math.lerp(headLerp, height, 20.0 * delta);
        camera.position = rl.Vector3{
            .x = player.position.x,
            .y = player.position.y + (BOTTOM_HEIGHT + headLerp),
            .z = player.position.z,
        };

        if (player.isGrounded and ((forward != 0) or (sideway != 0))) {
            headTimer += delta * 3.0;
            walkLerp = rl.math.lerp(walkLerp, 1.0, 10.0 * delta);
            camera.fovy = rl.math.lerp(camera.fovy, 55.0, 5.0 * delta);
        } else {
            walkLerp = rl.math.lerp(walkLerp, 0.0, 10.0 * delta);
            camera.fovy = rl.math.lerp(camera.fovy, 60.0, 5.0 * delta);
        }

        lean.x = rl.math.lerp(lean.x, sideway * 0.02, 10.0 * delta);
        lean.y = rl.math.lerp(lean.y, forward * 0.015, 10.0 * delta);

        UpdateCameraFPS(&camera);
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);

        {
            rl.beginMode3D(camera);
            defer rl.endMode3D();
            DrawLevel();
        }

        // Draw info box
        rl.drawRectangle(5, 5, 330, 75, rl.fade(.sky_blue, 0.5));
        rl.drawRectangleLines(5, 5, 330, 75, .blue);

        rl.drawText("Camera controls:", 15, 15, 10, .black);
        rl.drawText("- Move keys: W, A, S, D, Space, Left-Ctrl", 15, 30, 10, .black);
        rl.drawText("- Look around: arrow keys or mouse", 15, 45, 10, .black);
        rl.drawText(rl.textFormat(
            "- Velocity Len: (%06.3f)",
            .{rl.Vector2.length(.{ .x = player.velocity.x, .y = player.velocity.z })},
        ), 15, 60, 10, .black);

        //----------------------------------------------------------------------------------
    }
}

//----------------------------------------------------------------------------------
// Module Functions Definition
//----------------------------------------------------------------------------------
// Update body considering current world state
fn updateBody(body: *Body, rot: f32, side: f32, forward: f32, jumpPressed: bool, crouchHold: bool) void {
    var input: rl.Vector2 = .{ .x = side, .y = -forward };

    if (NORMALIZE_INPUT) {
        // Slow down diagonal movement
        if ((side != 0) and (forward != 0)) {
            input = input.normalize();
        }
    }

    const delta = rl.getFrameTime();

    if (!body.isGrounded) body.velocity.y -= GRAVITY * delta;

    if (body.isGrounded and jumpPressed) {
        body.velocity.y = JUMP_FORCE;
        body.isGrounded = false;

        // Sound can be played at this moment
        //SetSoundPitch(fxJump, 1.0f + (GetRandomValue(-100, 100)*0.001));
        //PlaySound(fxJump);
    }

    const front = rl.Vector3{ .x = @sin(rot), .y = 0.0, .z = @cos(rot) };
    const right = rl.Vector3{ .x = @cos(-rot), .y = 0.0, .z = @sin(-rot) };

    const desiredDir = rl.Vector3{
        .x = input.x * right.x + input.y * front.x,
        .y = 0.0,
        .z = input.x * right.z + input.y * front.z,
    };
    body.dir = body.dir.lerp(desiredDir, CONTROL * delta);

    const decel: f32 = if (body.isGrounded) FRICTION else AIR_DRAG;
    var hvel = rl.Vector3{
        .x = body.velocity.x * decel,
        .y = 0.0,
        .z = body.velocity.z * decel,
    };

    const hvelLength = hvel.length(); // Magnitude
    if (hvelLength < (MAX_SPEED * 0.01)) {
        hvel = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }

    // This is what creates strafing
    const speed = hvel.dotProduct(body.dir);

    // Whenever the amount of acceleration to add is clamped by the maximum acceleration constant,
    // a Player can make the speed faster by bringing the direction closer to horizontal velocity angle
    // More info here: https://youtu.be/v3zT3Z5apaM?t=165
    const maxSpeed: f32 = if (crouchHold) CROUCH_SPEED else MAX_SPEED;
    const accel = rl.math.clamp(maxSpeed - speed, 0.0, MAX_ACCEL * delta);

    hvel.x += body.dir.x * accel;
    hvel.z += body.dir.z * accel;

    body.velocity.x = hvel.x;
    body.velocity.z = hvel.z;

    body.position.x += body.velocity.x * delta;
    body.position.y += body.velocity.y * delta;
    body.position.z += body.velocity.z * delta;

    // Fancy collision system against the floor
    if (body.position.y <= 0.0) {
        body.position.y = 0.0;
        body.velocity.y = 0.0;
        body.isGrounded = true; // Enable jumping
    }
}

// Update camera for FPS behaviour
fn UpdateCameraFPS(camera: *rl.Camera) void {
    const up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
    const targetOffset = rl.Vector3{ .x = 0.0, .y = 0.0, .z = -1.0 };

    // Left and right
    const yaw = targetOffset.rotateByAxisAngle(up, lookRotation.x);

    // Clamp view up
    const maxAngleUp = up.angle(yaw) - 0.001; // avoid numerical errors
    if (-(lookRotation.y) > maxAngleUp) {
        lookRotation.y = -maxAngleUp;
    }

    // Clamp view down
    const maxAngleDown = up.negate().angle(yaw) * -1 + 0.001; // avoid numerical errors
    if (-(lookRotation.y) < maxAngleDown) {
        lookRotation.y = -maxAngleDown;
    }

    // Up and down
    const right = yaw.crossProduct(up).normalize();

    // Rotate view vector around right axis
    const pitchAngle = -lookRotation.y - lean.y;
    const pitch = yaw.rotateByAxisAngle(right, pitchAngle);

    // Head animation
    // Rotate up direction around forward axis
    const headSin = @sin(headTimer * std.math.pi);
    const headCos = @cos(headTimer * std.math.pi);
    const stepRotation = 0.01;
    camera.up = up.rotateByAxisAngle(pitch, headSin * stepRotation + lean.x);

    // Camera BOB
    const bobSide = 0.1;
    const bobUp = 0.15;
    var bobbing = right.scale(headSin * bobSide);
    bobbing.y = @abs(headCos * bobUp);

    camera.position = camera.position.add(bobbing.scale(walkLerp));
    camera.target = camera.position.add(pitch);
}

// Draw game level
fn DrawLevel() void {
    const floorExtent: i32 = 25;
    const tileSize = 5.0;
    const tileColor1 = rl.Color{ .r = 150, .g = 200, .b = 200, .a = 255 };

    // Floor tiles
    for (0..floorExtent * 2) |ySize| {
        for (0..floorExtent * 2) |xSize| {
            const y: i32 = @as(i32, @intCast(ySize)) - floorExtent;
            const x: i32 = @as(i32, @intCast(xSize)) - floorExtent;
            const yf: f32 = @floatFromInt(y);
            const xf: f32 = @floatFromInt(x);
            if ((y & 1) > 0 and (x & 1) > 0) {
                rl.drawPlane(
                    rl.Vector3{ .x = xf * tileSize, .y = 0.0, .z = yf * tileSize },
                    rl.Vector2{ .x = tileSize, .y = tileSize },
                    tileColor1,
                );
            } else if ((y & 1) == 0 and (x & 1) == 0) {
                rl.drawPlane(
                    rl.Vector3{ .x = xf * tileSize, .y = 0.0, .z = yf * tileSize },
                    rl.Vector2{ .x = tileSize, .y = tileSize },
                    .light_gray,
                );
            }
        }
    }

    const towerSize = rl.Vector3{ .x = 16.0, .y = 32.0, .z = 16.0 };
    const towerColor = rl.Color{ .r = 150, .g = 200, .b = 200, .a = 255 };

    var towerPos = rl.Vector3{ .x = 16.0, .y = 16.0, .z = 16.0 };
    rl.drawCubeV(towerPos, towerSize, towerColor);
    rl.drawCubeWiresV(towerPos, towerSize, .dark_blue);

    towerPos.x *= -1;
    rl.drawCubeV(towerPos, towerSize, towerColor);
    rl.drawCubeWiresV(towerPos, towerSize, .dark_blue);

    towerPos.z *= -1;
    rl.drawCubeV(towerPos, towerSize, towerColor);
    rl.drawCubeWiresV(towerPos, towerSize, .dark_blue);

    towerPos.x *= -1;
    rl.drawCubeV(towerPos, towerSize, towerColor);
    rl.drawCubeWiresV(towerPos, towerSize, .dark_blue);

    // Red sun
    rl.drawSphere(
        rl.Vector3{ .x = 300.0, .y = 300.0, .z = 0.0 },
        100.0,
        rl.Color{ .r = 255, .g = 0, .b = 0, .a = 255 },
    );
}
