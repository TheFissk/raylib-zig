//!*******************************************************************************************
//!
//!   raylib-zig port of the [core] example - automation events
//!
//!   Example complexity rating: [★★★☆] 3/4
//!
//!   Example originally created with raylib 5.0, last time updated with raylib 5.0
//!   Translated to raylib-zig by Timothy Fiss (@TheFissk)
//!
//!   Example based on 2d_camera_platformer example by arvyy (@arvyy)
//!
//!   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
//!   BSD-like license that allows static linking with closed source software
//!
//!   Copyright (c) 2023-2025 Ramon Santamaria (@raysan5)
//!
//!********************************************************************************************

const rl = @import("raylib");
const std = @import("std");

const GRAVITY = 400.0;
const PLAYER_JUMP_SPD = 350.0;
const PLAYER_HOR_SPD = 200.0;

const MAX_ENVIRONMENT_ELEMENTS = 5;

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------
const Player = struct {
    position: rl.Vector2,
    speed: f32,
    canJump: bool,
};

const EnvElement = struct {
    rect: rl.Rectangle,
    blocking: bool,
    color: rl.Color,
};

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib [core] example - automation events");
    defer rl.closeWindow();

    // Define player
    var player = Player{
        .position = rl.Vector2{ .x = 400, .y = 280 },
        .speed = 0,
        .canJump = false,
    };

    // Define environment elements (platforms)
    const envElements = [MAX_ENVIRONMENT_ELEMENTS]EnvElement{
        .{ .rect = rl.Rectangle{ .x = 0, .y = 0, .width = 1000, .height = 400 }, .blocking = false, .color = .light_gray },
        .{ .rect = rl.Rectangle{ .x = 0, .y = 400, .width = 1000, .height = 200 }, .blocking = true, .color = .gray },
        .{ .rect = rl.Rectangle{ .x = 300, .y = 200, .width = 400, .height = 10 }, .blocking = true, .color = .gray },
        .{ .rect = rl.Rectangle{ .x = 250, .y = 300, .width = 100, .height = 10 }, .blocking = true, .color = .gray },
        .{ .rect = rl.Rectangle{ .x = 650, .y = 300, .width = 100, .height = 10 }, .blocking = true, .color = .gray },
    };

    // Define camera
    var camera = rl.Camera2D{
        .target = player.position,
        .offset = rl.Vector2{ .x = screenWidth / 2.0, .y = screenHeight / 2.0 },
        .rotation = 0.0,
        .zoom = 1.0,
    };

    // Automation events
    var aelist = rl.loadAutomationEventList(""); // Initialize list of automation events to record new events
    rl.setAutomationEventList(&aelist);
    var eventRecording = false;
    var eventPlaying = false;

    var frameCounter: u32 = 0;
    var playFrameCounter: u32 = 0;
    var currentPlayFrame: u32 = 0;

    rl.setTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update
        //----------------------------------------------------------------------------------
        const deltaTime = 0.015; //GetFrameTime();

        // Dropped files logic
        //----------------------------------------------------------------------------------
        if (rl.isFileDropped()) {
            const droppedFiles = rl.loadDroppedFiles();
            defer rl.unloadDroppedFiles(droppedFiles); // Unload filepaths from memory

            // Supports loading .rgs style files (text or binary) and .png style palette images
            const droppedFile = std.mem.span(droppedFiles.paths[0]);
            if (rl.isFileExtension(droppedFile, ".txt;.rae")) {
                aelist.unload();
                aelist = rl.loadAutomationEventList(droppedFile);

                eventRecording = false;

                // Reset scene state to play
                eventPlaying = true;
                playFrameCounter = 0;
                currentPlayFrame = 0;

                player.position = rl.Vector2{ .x = 400, .y = 280 };
                player.speed = 0;
                player.canJump = false;

                camera.target = player.position;
                camera.offset = rl.Vector2{ .x = screenWidth / 2.0, .y = screenHeight / 2.0 };
                camera.rotation = 0.0;
                camera.zoom = 1.0;
            }
        }
        //----------------------------------------------------------------------------------

        // Update player
        //----------------------------------------------------------------------------------
        if (rl.isKeyDown(.left)) player.position.x -= PLAYER_HOR_SPD * deltaTime;
        if (rl.isKeyDown(.right)) player.position.x += PLAYER_HOR_SPD * deltaTime;
        if (rl.isKeyDown(.space) and player.canJump) {
            player.speed = -PLAYER_JUMP_SPD;
            player.canJump = false;
        }

        var hitObstacle = false;
        for (&envElements) |*element| {
            var p = player.position;
            if (element.blocking and
                element.rect.x <= p.x and
                element.rect.x + element.rect.width >= p.x and
                element.rect.y >= p.y and
                element.rect.y <= p.y + player.speed * deltaTime)
            {
                hitObstacle = true;
                player.speed = 0.0;
                p.y = element.rect.y;
            }
        }

        if (!hitObstacle) {
            player.position.y += player.speed * deltaTime;
            player.speed += GRAVITY * deltaTime;
            player.canJump = false;
        } else player.canJump = true;

        if (rl.isKeyPressed(.r)) {
            // Reset game state
            player.position = rl.Vector2{ .x = 400, .y = 280 };
            player.speed = 0;
            player.canJump = false;

            camera.target = player.position;
            camera.offset = rl.Vector2{ .x = screenWidth / 2.0, .y = screenHeight / 2.0 };
            camera.rotation = 0.0;
            camera.zoom = 1.0;
        }
        //----------------------------------------------------------------------------------

        // Events playing
        // NOTE: Logic must be before Camera update because it depends on mouse-wheel value,
        // that can be set by the played event... but some other inputs could be affected
        //----------------------------------------------------------------------------------
        if (eventPlaying) {
            // NOTE: Multiple events could be executed in a single frame
            while (playFrameCounter == aelist.events[currentPlayFrame].frame) {
                rl.playAutomationEvent(aelist.events[currentPlayFrame]);
                currentPlayFrame += 1;

                if (currentPlayFrame == aelist.count) {
                    eventPlaying = false;
                    currentPlayFrame = 0;
                    playFrameCounter = 0;

                    rl.traceLog(.info, "FINISH PLAYING!", .{});
                    break;
                }
            }

            playFrameCounter += 1;
        }
        //----------------------------------------------------------------------------------

        // Update camera
        //----------------------------------------------------------------------------------
        camera.target = player.position;
        camera.offset = rl.Vector2{ .x = screenWidth / 2.0, .y = screenHeight / 2.0 };
        var minX: f32 = 1000.0;
        var minY: f32 = 1000.0;
        var maxX: f32 = -1000.0;
        var maxY: f32 = -1000.0;

        // WARNING: On event replay, mouse-wheel internal value is set
        camera.zoom += (rl.getMouseWheelMove() * 0.05);
        if (camera.zoom > 3.0) {
            camera.zoom = 3.0;
        } else if (camera.zoom < 0.25) {
            camera.zoom = 0.25;
        }

        for (&envElements) |*element| {
            minX = @min(element.rect.x, minX);
            maxX = @max(element.rect.x + element.rect.width, maxX);
            minY = @min(element.rect.y, minY);
            maxY = @max(element.rect.y + element.rect.height, maxY);
        }

        const max = rl.getWorldToScreen2D(rl.Vector2{ .x = maxX, .y = maxY }, camera);
        const min = rl.getWorldToScreen2D(rl.Vector2{ .x = minX, .y = minY }, camera);

        if (max.x < screenWidth) {
            camera.offset.x = screenWidth - (max.x - screenWidth / 2);
        }
        if (max.y < screenHeight) {
            camera.offset.y = screenHeight - (max.y - screenHeight / 2);
        }
        if (min.x > 0) {
            camera.offset.x = screenWidth / 2 - min.x;
        }
        if (min.y > 0) {
            camera.offset.y = screenHeight / 2 - min.y;
        }
        //----------------------------------------------------------------------------------

        // Events management
        if (rl.isKeyPressed(.s)) // Toggle events recording
        {
            if (!eventPlaying) {
                if (eventRecording) {
                    rl.stopAutomationEventRecording();
                    eventRecording = false;

                    _ = rl.exportAutomationEventList(aelist, "automation.rae");

                    rl.traceLog(.info, "RECORDED FRAMES: %i", .{aelist.count});
                } else {
                    rl.setAutomationEventBaseFrame(180);
                    rl.startAutomationEventRecording();
                    eventRecording = true;
                }
            }
        } else if (rl.isKeyPressed(.a)) // Toggle events playing (WARNING: Starts next frame)
        {
            if (!eventRecording and (aelist.count > 0)) {
                // Reset scene state to play
                eventPlaying = true;
                playFrameCounter = 0;
                currentPlayFrame = 0;

                player.position = rl.Vector2{ .x = 400, .y = 280 };
                player.speed = 0;
                player.canJump = false;

                camera.target = player.position;
                camera.offset = rl.Vector2{ .x = screenWidth / 2.0, .y = screenHeight / 2.0 };
                camera.rotation = 0.0;
                camera.zoom = 1.0;
            }
        }

        frameCounter = if (eventRecording or eventPlaying) frameCounter + 1 else 0;
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.light_gray);

        {
            rl.beginMode2D(camera);
            defer rl.endMode2D();

            // Draw environment elements
            for (envElements) |element| {
                rl.drawRectangleRec(element.rect, element.color);
            }

            // Draw player rectangle
            rl.drawRectangleRec(rl.Rectangle{
                .x = player.position.x - 20,
                .y = player.position.y - 40,
                .width = 40,
                .height = 40,
            }, .red);
        }

        // Draw game controls
        rl.drawRectangle(10, 10, 290, 145, rl.fade(.sky_blue, 0.5));
        rl.drawRectangleLines(10, 10, 290, 145, rl.fade(.blue, 0.8));

        rl.drawText("Controls:", 20, 20, 10, .black);
        rl.drawText("- RIGHT | LEFT: Player movement", 30, 40, 10, .dark_gray);
        rl.drawText("- SPACE: Player jump", 30, 60, 10, .dark_gray);
        rl.drawText("- R: Reset game state", 30, 80, 10, .dark_gray);

        rl.drawText("- S: START/STOP RECORDING INPUT EVENTS", 30, 110, 10, .black);
        rl.drawText("- A: REPLAY LAST RECORDED INPUT EVENTS", 30, 130, 10, .black);

        // Draw automation events recording indicator
        if (eventRecording) {
            rl.drawRectangle(10, 160, 290, 30, rl.fade(.red, 0.3));
            rl.drawRectangleLines(10, 160, 290, 30, rl.fade(.maroon, 0.8));
            rl.drawCircle(30, 175, 10, .maroon);

            if (((frameCounter / 15) % 2) == 1) {
                rl.drawText(rl.textFormat(
                    "RECORDING EVENTS... [%i]",
                    .{aelist.count},
                ), 50, 170, 10, .maroon);
            }
        } else if (eventPlaying) {
            rl.drawRectangle(10, 160, 290, 30, rl.fade(.lime, 0.3));
            rl.drawRectangleLines(10, 160, 290, 30, rl.fade(.dark_green, 0.8));

            rl.drawTriangle(rl.Vector2{ .x = 20, .y = 155 + 10 }, rl.Vector2{ .x = 20, .y = 155 + 30 }, rl.Vector2{ .x = 40, .y = 155 + 20 }, .dark_green);

            if (((frameCounter / 15) % 2) == 1) rl.drawText(rl.textFormat("PLAYING RECORDED EVENTS... [%i]", .{currentPlayFrame}), 50, 170, 10, .dark_green);
        }

        //----------------------------------------------------------------------------------
    }
}
