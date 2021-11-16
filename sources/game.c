#include"game.h"

#include<stdlib.h>

#include"raylib.h"
#include"raymath.h"
#include"rlgl.h"

#include"tree.h"

void StartGame(s_game* game){
    InitWindow(game->window_size.x, game->window_size.y, game->title);
    
    // Setup camera
    game->camera.zoom = 0.5f;

    // Setup game values
    game->fractal_tree_angle = 30;
    game->fractal_tree_start_length = 350;

    SetTargetFPS(60);
    RunGame(game); // Go further into it by starting the game loop
}

void RunGame(s_game* game) {


    // Setup post-processing stuff
    Shader pp_shader = LoadShader(0, TextFormat(ASSETS_PATH"postprocessing.glsl", 330)); // Load bloom shader
    RenderTexture2D framebuffer_texture = LoadRenderTexture(game->window_size.x, game->window_size.y);

    while(!WindowShouldClose()){

        // Update input related stuff
        InputGame(game);

        BeginTextureMode(framebuffer_texture); // Enable so we draw to the framebuffer texture!
        BeginMode2D(game->camera);

            ClearBackground(SKYBLUE);

            /* Draws the basis vectors from 0, 0 on x,y axis */
            //DrawCoordinateAxis();

            rlPushMatrix();
            rlTranslatef(game->window_size.x, game->window_size.y*2, 0); // Translate to middle and bottom 
            RecursiveTreeDraw(game->fractal_tree_start_length, 
            game->fractal_tree_start_length, 
            game->fractal_tree_angle);
            rlPopMatrix();

        EndMode2D();
        EndTextureMode(); // End framebuffer texture

        BeginDrawing(); // Draw the actual post processed framebuffer

            ClearBackground(WHITE);
            BeginShaderMode(pp_shader);
                // Flip the y due to how the default opengl coordinates work (left-bottom)
                DrawTextureRec(framebuffer_texture.texture, (Rectangle){0, 0, (float)+framebuffer_texture.texture.width, (float)-framebuffer_texture.texture.height}, (Vector2){0.0, 0.0}, WHITE);
            EndShaderMode();

        EndDrawing();
    }

    CloseWindow();
}

void EndGame(s_game* game) {

}

void DrawCoordinateAxis() {
    Vector2 origin = (Vector2){ 0.0f, 0.0f };
    float axisThickness = 8.0f;
    float axisScale = 500.0f;
    Color axisColor = RED;

    DrawLineEx(origin, Vector2Add(origin, (Vector2) { axisScale, 0.0f }), axisThickness, axisColor); // X-axis
    DrawLineEx(origin, Vector2Add(origin, (Vector2) { 0.0f, axisScale }), axisThickness, axisColor); // Y-axis
}

void InputGame(s_game* game) {
    Vector2 moveVector = { 0 };
    
    if (IsKeyDown(KEY_D)) {
        moveVector.x--;
    }
    else if (IsKeyDown(KEY_A)) {
        moveVector.x++;
    }

    if (IsKeyDown(KEY_S)) {
        moveVector.y--;
    }
    else if (IsKeyDown(KEY_W)) {
        moveVector.y++;
    }

    float cameraSpeed = 10.0f;

    // Scale with delta time
    Vector2Scale(moveVector, cameraSpeed*GetFrameTime());

    // Move camera
    game->camera.offset = Vector2Add(game->camera.offset, moveVector);

    // Angle input thing
    if(IsKeyDown(KEY_UP)){
        game->fractal_tree_angle += 10.0f * GetFrameTime();
    }else if(IsKeyDown(KEY_DOWN)){
        game->fractal_tree_angle += -10.0f * GetFrameTime();
    }    

}