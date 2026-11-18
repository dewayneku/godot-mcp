#!/usr/bin/env -S godot --headless --script
extends SceneTree

# Debug mode flag
var debug_mode = false
# Set by fail(); keeps the final quit() from overwriting the error exit code
var has_failed = false

func _init():
    var args = OS.get_cmdline_args()
    
    # Check for debug flag
    debug_mode = "--debug-godot" in args
    
    # Find the script argument and determine the positions of operation and params
    var script_index = args.find("--script")
    if script_index == -1:
        log_error("Could not find --script argument")
        quit(1)
    
    # The operation should be 2 positions after the script path (script_index + 1 is the script path itself)
    var operation_index = script_index + 2
    # The params should be 3 positions after the script path
    var params_index = script_index + 3
    
    if args.size() <= params_index:
        log_error("Usage: godot --headless --script godot_operations.gd <operation> <json_params>")
        log_error("Not enough command-line arguments provided.")
        quit(1)
    
    # Log all arguments for debugging
    log_debug("All arguments: " + str(args))
    log_debug("Script index: " + str(script_index))
    log_debug("Operation index: " + str(operation_index))
    log_debug("Params index: " + str(params_index))
    
    var operation = args[operation_index]
    var params_json = args[params_index]
    
    log_info("Operation: " + operation)
    log_debug("Params JSON: " + params_json)
    
    # Parse JSON using Godot 4.x API
    var json = JSON.new()
    var error = json.parse(params_json)
    var params = null
    
    if error == OK:
        params = json.get_data()
    else:
        log_error("Failed to parse JSON parameters: " + params_json)
        log_error("JSON Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
        quit(1)
    
    # An empty {} is valid (and falsy in GDScript), so only reject non-objects
    if typeof(params) != TYPE_DICTIONARY:
        log_error("JSON parameters must be an object: " + params_json)
        quit(1)
        return
    
    log_info("Executing operation: " + operation)
    
    match operation:
        "create_scene":
            create_scene(params)
        "add_node":
            add_node(params)
        "load_sprite":
            load_sprite(params)
        "export_mesh_library":
            export_mesh_library(params)
        "save_scene":
            save_scene(params)
        "get_uid":
            get_uid(params)
        "resave_resources":
            resave_resources(params)
        "get_scene_tree":
            get_scene_tree(params)
        "set_node_properties":
            set_node_properties(params)
        "attach_script":
            attach_script(params)
        "validate_scripts":
            validate_scripts(params)
        _:
            log_error("Unknown operation: " + operation)
            quit(1)
            return

    if not has_failed:
        quit()

# Logging functions
func log_debug(message):
    if debug_mode:
        print("[DEBUG] " + message)

func log_info(message):
    print("[INFO] " + message)

func log_error(message):
    printerr("[ERROR] " + message)

# Get a script by registered class name.
# Only looks up names via the project's global class registry. Raw paths
# (e.g. "res://evil.gd") are intentionally not accepted here to prevent
# arbitrary script instantiation from agent-supplied input.
func get_script_by_name(name_of_class):
    if debug_mode:
        print("Attempting to get script for class: " + name_of_class)

    # Search for it in the global class registry if it's a class name
    var global_classes = ProjectSettings.get_global_class_list()
    if debug_mode:
        print("Searching through " + str(global_classes.size()) + " global classes")
    
    for global_class in global_classes:
        var found_name_of_class = global_class["class"]
        var found_path = global_class["path"]
        
        if found_name_of_class == name_of_class:
            if debug_mode:
                print("Found matching class in registry: " + found_name_of_class + " at path: " + found_path)
            var script = load(found_path) as Script
            if script:
                if debug_mode:
                    print("Successfully loaded script from registry")
                return script
            else:
                printerr("Failed to load script from registry path: " + found_path)
                break
    
    printerr("Could not find script for class: " + name_of_class)
    return null

# Instantiate a class by name
func instantiate_class(name_of_class):
    if name_of_class.is_empty():
        printerr("Cannot instantiate class: name is empty")
        return null
    
    var result = null
    if debug_mode:
        print("Attempting to instantiate class: " + name_of_class)
    
    # Check if it's a built-in class
    if ClassDB.class_exists(name_of_class):
        if debug_mode:
            print("Class exists in ClassDB, using ClassDB.instantiate()")
        if ClassDB.can_instantiate(name_of_class):
            result = ClassDB.instantiate(name_of_class)
            if result == null:
                printerr("ClassDB.instantiate() returned null for class: " + name_of_class)
        else:
            printerr("Class exists but cannot be instantiated: " + name_of_class)
            printerr("This may be an abstract class or interface that cannot be directly instantiated")
    else:
        # Try to get the script
        if debug_mode:
            print("Class not found in ClassDB, trying to get script")
        var script = get_script_by_name(name_of_class)
        if script is GDScript:
            if debug_mode:
                print("Found GDScript, creating instance")
            result = script.new()
        else:
            printerr("Failed to get script for class: " + name_of_class)
            return null
    
    if result == null:
        printerr("Failed to instantiate class: " + name_of_class)
    elif debug_mode:
        print("Successfully instantiated class: " + name_of_class + " of type: " + result.get_class())
    
    return result

# Create a new scene with a specified root node type
func create_scene(params):
    print("Creating scene: " + params.scene_path)
    
    # Get project paths and log them for debugging
    var project_res_path = "res://"
    var project_user_path = "user://"
    var global_res_path = ProjectSettings.globalize_path(project_res_path)
    var global_user_path = ProjectSettings.globalize_path(project_user_path)
    
    if debug_mode:
        print("Project paths:")
        print("- res:// path: " + project_res_path)
        print("- user:// path: " + project_user_path)
        print("- Globalized res:// path: " + global_res_path)
        print("- Globalized user:// path: " + global_user_path)
        
        # Print some common environment variables for debugging
        print("Environment variables:")
        var env_vars = ["PATH", "HOME", "USER", "TEMP", "GODOT_PATH"]
        for env_var in env_vars:
            if OS.has_environment(env_var):
                print("  " + env_var + " = " + OS.get_environment(env_var))
    
    # Normalize the scene path
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    if debug_mode:
        print("Scene path (with res://): " + full_scene_path)
    
    # Convert resource path to an absolute path
    var absolute_scene_path = ProjectSettings.globalize_path(full_scene_path)
    if debug_mode:
        print("Absolute scene path: " + absolute_scene_path)
    
    # Get the scene directory paths
    var scene_dir_res = full_scene_path.get_base_dir()
    var scene_dir_abs = absolute_scene_path.get_base_dir()
    if debug_mode:
        print("Scene directory (resource path): " + scene_dir_res)
        print("Scene directory (absolute path): " + scene_dir_abs)
    
    # Only do extensive testing in debug mode
    if debug_mode:
        # Try to create a simple test file in the project root to verify write access
        var initial_test_file_path = "res://godot_mcp_test_write.tmp"
        var initial_test_file = FileAccess.open(initial_test_file_path, FileAccess.WRITE)
        if initial_test_file:
            initial_test_file.store_string("Test write access")
            initial_test_file.close()
            print("Successfully wrote test file to project root: " + initial_test_file_path)
            
            # Verify the test file exists
            var initial_test_file_exists = FileAccess.file_exists(initial_test_file_path)
            print("Test file exists check: " + str(initial_test_file_exists))
            
            # Clean up the test file
            if initial_test_file_exists:
                var remove_error = DirAccess.remove_absolute(ProjectSettings.globalize_path(initial_test_file_path))
                print("Test file removal result: " + str(remove_error))
        else:
            var write_error = FileAccess.get_open_error()
            printerr("Failed to write test file to project root: " + str(write_error))
            printerr("This indicates a serious permission issue with the project directory")
    
    # Use traditional if-else statement for better compatibility
    var root_node_type = "Node2D"  # Default value
    if params.has("root_node_type"):
        root_node_type = params.root_node_type
    if debug_mode:
        print("Root node type: " + root_node_type)
    
    # Create the root node
    var scene_root = instantiate_class(root_node_type)
    if not scene_root:
        printerr("Failed to instantiate node of type: " + root_node_type)
        printerr("Make sure the class exists and can be instantiated")
        printerr("Check if the class is registered in ClassDB or available as a script")
        quit(1)
    
    # Name the root like the Godot editor does: "player_ship.tscn" -> "PlayerShip"
    if params.has("root_node_name") and str(params.root_node_name) != "":
        scene_root.name = str(params.root_node_name)
    else:
        scene_root.name = params.scene_path.get_file().get_basename().to_pascal_case()
    if debug_mode:
        print("Root node created with name: " + scene_root.name)
    
    # Set the owner of the root node to itself (important for scene saving)
    scene_root.owner = scene_root
    
    # Pack the scene
    var packed_scene = PackedScene.new()
    var result = packed_scene.pack(scene_root)
    if debug_mode:
        print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")
    
    if result == OK:
        # Only do extensive testing in debug mode
        if debug_mode:
            # First, let's verify we can write to the project directory
            print("Testing write access to project directory...")
            var test_write_path = "res://test_write_access.tmp"
            var test_write_abs = ProjectSettings.globalize_path(test_write_path)
            var test_file = FileAccess.open(test_write_path, FileAccess.WRITE)
            
            if test_file:
                test_file.store_string("Write test")
                test_file.close()
                print("Successfully wrote test file to project directory")
                
                # Clean up test file
                if FileAccess.file_exists(test_write_path):
                    var remove_error = DirAccess.remove_absolute(test_write_abs)
                    print("Test file removal result: " + str(remove_error))
            else:
                var write_error = FileAccess.get_open_error()
                printerr("Failed to write test file to project directory: " + str(write_error))
                printerr("This may indicate permission issues with the project directory")
                # Continue anyway, as the scene directory might still be writable
        
        # Ensure the scene directory exists using DirAccess
        if debug_mode:
            print("Ensuring scene directory exists...")
        
        # Get the scene directory relative to res://
        var scene_dir_relative = scene_dir_res.substr(6)  # Remove "res://" prefix
        if debug_mode:
            print("Scene directory (relative to res://): " + scene_dir_relative)
        
        # Create the directory if needed
        if not scene_dir_relative.is_empty():
            # First check if it exists
            var dir_exists = DirAccess.dir_exists_absolute(scene_dir_abs)
            if debug_mode:
                print("Directory exists check (absolute): " + str(dir_exists))
            
            if not dir_exists:
                if debug_mode:
                    print("Directory doesn't exist, creating: " + scene_dir_relative)
                
                # Try to create the directory using DirAccess
                var dir = DirAccess.open("res://")
                if dir == null:
                    var open_error = DirAccess.get_open_error()
                    printerr("Failed to open res:// directory: " + str(open_error))
                    
                    # Try alternative approach with absolute path
                    if debug_mode:
                        print("Trying alternative directory creation approach...")
                    var make_dir_error = DirAccess.make_dir_recursive_absolute(scene_dir_abs)
                    if debug_mode:
                        print("Make directory result (absolute): " + str(make_dir_error))
                    
                    if make_dir_error != OK:
                        printerr("Failed to create directory using absolute path")
                        printerr("Error code: " + str(make_dir_error))
                        quit(1)
                else:
                    # Create the directory using the DirAccess instance
                    if debug_mode:
                        print("Creating directory using DirAccess: " + scene_dir_relative)
                    var make_dir_error = dir.make_dir_recursive(scene_dir_relative)
                    if debug_mode:
                        print("Make directory result: " + str(make_dir_error))
                    
                    if make_dir_error != OK:
                        printerr("Failed to create directory: " + scene_dir_relative)
                        printerr("Error code: " + str(make_dir_error))
                        quit(1)
                
                # Verify the directory was created
                dir_exists = DirAccess.dir_exists_absolute(scene_dir_abs)
                if debug_mode:
                    print("Directory exists check after creation: " + str(dir_exists))
                
                if not dir_exists:
                    printerr("Directory reported as created but does not exist: " + scene_dir_abs)
                    printerr("This may indicate a problem with path resolution or permissions")
                    quit(1)
            elif debug_mode:
                print("Directory already exists: " + scene_dir_abs)
        
        # Save the scene
        if debug_mode:
            print("Saving scene to: " + full_scene_path)
        var save_error = ResourceSaver.save(packed_scene, full_scene_path)
        if debug_mode:
            print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")
        
        if save_error == OK:
            ensure_scene_uid(full_scene_path)
            # Only do extensive testing in debug mode
            if debug_mode:
                # Wait a moment to ensure file system has time to complete the write
                print("Waiting for file system to complete write operation...")
                OS.delay_msec(500)  # 500ms delay
                
                # Verify the file was actually created using multiple methods
                var file_check_abs = FileAccess.file_exists(absolute_scene_path)
                print("File exists check (absolute path): " + str(file_check_abs))
                
                var file_check_res = FileAccess.file_exists(full_scene_path)
                print("File exists check (resource path): " + str(file_check_res))
                
                var res_exists = ResourceLoader.exists(full_scene_path)
                print("Resource exists check: " + str(res_exists))
                
                # If file doesn't exist by absolute path, try to create a test file in the same directory
                if not file_check_abs and not file_check_res:
                    printerr("Scene file not found after save. Trying to diagnose the issue...")
                    
                    # Try to write a test file to the same directory
                    var test_scene_file_path = scene_dir_res + "/test_scene_file.tmp"
                    var test_scene_file = FileAccess.open(test_scene_file_path, FileAccess.WRITE)
                    
                    if test_scene_file:
                        test_scene_file.store_string("Test scene directory write")
                        test_scene_file.close()
                        print("Successfully wrote test file to scene directory: " + test_scene_file_path)
                        
                        # Check if the test file exists
                        var test_file_exists = FileAccess.file_exists(test_scene_file_path)
                        print("Test file exists: " + str(test_file_exists))
                        
                        if test_file_exists:
                            # Directory is writable, so the issue is with scene saving
                            printerr("Directory is writable but scene file wasn't created.")
                            printerr("This suggests an issue with ResourceSaver.save() or the packed scene.")
                            
                            # Try saving with a different approach
                            print("Trying alternative save approach...")
                            var alt_save_error = ResourceSaver.save(packed_scene, test_scene_file_path + ".tscn")
                            print("Alternative save result: " + str(alt_save_error))
                            
                            # Clean up test files
                            DirAccess.remove_absolute(ProjectSettings.globalize_path(test_scene_file_path))
                            if alt_save_error == OK:
                                DirAccess.remove_absolute(ProjectSettings.globalize_path(test_scene_file_path + ".tscn"))
                        else:
                            printerr("Test file couldn't be verified. This suggests filesystem access issues.")
                    else:
                        var write_error = FileAccess.get_open_error()
                        printerr("Failed to write test file to scene directory: " + str(write_error))
                        printerr("This confirms there are permission or path issues with the scene directory.")
                    
                    # Return error since we couldn't create the scene file
                    printerr("Failed to create scene: " + params.scene_path)
                    quit(1)
                
                # If we get here, at least one of our file checks passed
                if file_check_abs or file_check_res or res_exists:
                    print("Scene file verified to exist!")
                    
                    # Try to load the scene to verify it's valid
                    var test_load = ResourceLoader.load(full_scene_path)
                    if test_load:
                        print("Scene created and verified successfully at: " + params.scene_path)
                        print("Scene file can be loaded correctly.")
                    else:
                        print("Scene file exists but cannot be loaded. It may be corrupted or incomplete.")
                        # Continue anyway since the file exists
                    
                    print("Scene created successfully at: " + params.scene_path)
                else:
                    printerr("All file existence checks failed despite successful save operation.")
                    printerr("This indicates a serious issue with file system access or path resolution.")
                    quit(1)
            else:
                # In non-debug mode, just check if the file exists
                var file_exists = FileAccess.file_exists(full_scene_path)
                if file_exists:
                    print("Scene created successfully at: " + params.scene_path)
                else:
                    printerr("Failed to create scene: " + params.scene_path)
                    quit(1)
        else:
            # Handle specific error codes
            var error_message = "Failed to save scene. Error code: " + str(save_error)
            
            if save_error == ERR_CANT_CREATE:
                error_message += " (ERR_CANT_CREATE - Cannot create the scene file)"
            elif save_error == ERR_CANT_OPEN:
                error_message += " (ERR_CANT_OPEN - Cannot open the scene file for writing)"
            elif save_error == ERR_FILE_CANT_WRITE:
                error_message += " (ERR_FILE_CANT_WRITE - Cannot write to the scene file)"
            elif save_error == ERR_FILE_NO_PERMISSION:
                error_message += " (ERR_FILE_NO_PERMISSION - No permission to write the scene file)"
            
            printerr(error_message)
            quit(1)
    else:
        printerr("Failed to pack scene: " + str(result))
        printerr("Error code: " + str(result))
        quit(1)

# Add a node to an existing scene
func add_node(params):
    print("Adding node to scene: " + params.scene_path)
    
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    if debug_mode:
        print("Scene path (with res://): " + full_scene_path)
    
    var absolute_scene_path = ProjectSettings.globalize_path(full_scene_path)
    if debug_mode:
        print("Absolute scene path: " + absolute_scene_path)
    
    if not FileAccess.file_exists(absolute_scene_path):
        printerr("Scene file does not exist at: " + absolute_scene_path)
        quit(1)
    
    var scene = load(full_scene_path)
    if not scene:
        printerr("Failed to load scene: " + full_scene_path)
        quit(1)
    
    if debug_mode:
        print("Scene loaded successfully")
    var scene_root = scene.instantiate()
    if debug_mode:
        print("Scene instantiated")
    
    # Use traditional if-else statement for better compatibility
    var parent_path = "root"  # Default value
    if params.has("parent_node_path"):
        parent_path = params.parent_node_path
    if debug_mode:
        print("Parent path: " + parent_path)
    
    var parent = scene_root
    if parent_path != "root":
        parent = scene_root.get_node(parent_path.replace("root/", ""))
        if not parent:
            printerr("Parent node not found: " + parent_path)
            quit(1)
    if debug_mode:
        print("Parent node found: " + parent.name)
    
    if debug_mode:
        print("Instantiating node of type: " + params.node_type)
    var new_node = instantiate_class(params.node_type)
    if not new_node:
        printerr("Failed to instantiate node of type: " + params.node_type)
        printerr("Make sure the class exists and can be instantiated")
        printerr("Check if the class is registered in ClassDB or available as a script")
        quit(1)
    new_node.name = params.node_name
    if debug_mode:
        print("New node created with name: " + new_node.name)
    
    if params.has("properties"):
        if debug_mode:
            print("Setting properties on node")
        var properties = params.properties
        for property in properties:
            if debug_mode:
                print("Setting property: " + property + " = " + str(properties[property]))
            var value = properties[property]
            if typeof(value) == TYPE_STRING and value.begins_with("res://"):
                value = load(value)
                if debug_mode:
                    print("Loaded resource for property: " + property + " -> " + str(value))
            new_node.set(property, value)
    
    parent.add_child(new_node)
    new_node.owner = scene_root
    if debug_mode:
        print("Node added to parent and ownership set")
    
    var packed_scene = PackedScene.new()
    var result = packed_scene.pack(scene_root)
    if debug_mode:
        print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")
    
    if result == OK:
        if debug_mode:
            print("Saving scene to: " + absolute_scene_path)
        var save_error = save_preserving_uid(packed_scene, absolute_scene_path)
        if debug_mode:
            print("Save result: " + str(save_error) + " (OK=" + str(OK) + ")")
        if save_error == OK:
            if debug_mode:
                var file_check_after = FileAccess.file_exists(absolute_scene_path)
                print("File exists check after save: " + str(file_check_after))
                if file_check_after:
                    print("Node '" + params.node_name + "' of type '" + params.node_type + "' added successfully")
                else:
                    printerr("File reported as saved but does not exist at: " + absolute_scene_path)
            else:
                print("Node '" + params.node_name + "' of type '" + params.node_type + "' added successfully")
        else:
            printerr("Failed to save scene: " + str(save_error))
    else:
        printerr("Failed to pack scene: " + str(result))

# Load a sprite into a Sprite2D node
func load_sprite(params):
    print("Loading sprite into scene: " + params.scene_path)
    
    # Ensure the scene path starts with res:// for Godot's resource system
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    
    if debug_mode:
        print("Full scene path (with res://): " + full_scene_path)
    
    # Check if the scene file exists
    var file_check = FileAccess.file_exists(full_scene_path)
    if debug_mode:
        print("Scene file exists check: " + str(file_check))
    
    if not file_check:
        printerr("Scene file does not exist at: " + full_scene_path)
        # Get the absolute path for reference
        var absolute_path = ProjectSettings.globalize_path(full_scene_path)
        printerr("Absolute file path that doesn't exist: " + absolute_path)
        quit(1)
    
    # Ensure the texture path starts with res:// for Godot's resource system
    var full_texture_path = params.texture_path
    if not full_texture_path.begins_with("res://"):
        full_texture_path = "res://" + full_texture_path
    
    if debug_mode:
        print("Full texture path (with res://): " + full_texture_path)
    
    # Load the scene
    var scene = load(full_scene_path)
    if not scene:
        printerr("Failed to load scene: " + full_scene_path)
        quit(1)
    
    if debug_mode:
        print("Scene loaded successfully")
    
    # Instance the scene
    var scene_root = scene.instantiate()
    if debug_mode:
        print("Scene instantiated")
    
    # Find the sprite node
    var node_path = params.node_path
    if debug_mode:
        print("Original node path: " + node_path)
    
    if node_path.begins_with("root/"):
        node_path = node_path.substr(5)  # Remove "root/" prefix
        if debug_mode:
            print("Node path after removing 'root/' prefix: " + node_path)
    
    var sprite_node = null
    if node_path == "":
        # If no node path, assume root is the sprite
        sprite_node = scene_root
        if debug_mode:
            print("Using root node as sprite node")
    else:
        sprite_node = scene_root.get_node(node_path)
        if sprite_node and debug_mode:
            print("Found sprite node: " + sprite_node.name)
    
    if not sprite_node:
        printerr("Node not found: " + params.node_path)
        quit(1)
    
    # Check if the node is a Sprite2D or compatible type
    if debug_mode:
        print("Node class: " + sprite_node.get_class())
    if not (sprite_node is Sprite2D or sprite_node is Sprite3D or sprite_node is TextureRect):
        printerr("Node is not a sprite-compatible type: " + sprite_node.get_class())
        quit(1)
    
    # Load the texture
    if debug_mode:
        print("Loading texture from: " + full_texture_path)
    var texture = load(full_texture_path)
    if not texture:
        printerr("Failed to load texture: " + full_texture_path)
        quit(1)
    
    if debug_mode:
        print("Texture loaded successfully")
    
    # Set the texture on the sprite
    if sprite_node is Sprite2D or sprite_node is Sprite3D:
        sprite_node.texture = texture
        if debug_mode:
            print("Set texture on Sprite2D/Sprite3D node")
    elif sprite_node is TextureRect:
        sprite_node.texture = texture
        if debug_mode:
            print("Set texture on TextureRect node")
    
    # Save the modified scene
    var packed_scene = PackedScene.new()
    var result = packed_scene.pack(scene_root)
    if debug_mode:
        print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")
    
    if result == OK:
        if debug_mode:
            print("Saving scene to: " + full_scene_path)
        var error = save_preserving_uid(packed_scene, full_scene_path)
        if debug_mode:
            print("Save result: " + str(error) + " (OK=" + str(OK) + ")")
        
        if error == OK:
            # Verify the file was actually updated
            if debug_mode:
                var file_check_after = FileAccess.file_exists(full_scene_path)
                print("File exists check after save: " + str(file_check_after))
                
                if file_check_after:
                    print("Sprite loaded successfully with texture: " + full_texture_path)
                    # Get the absolute path for reference
                    var absolute_path = ProjectSettings.globalize_path(full_scene_path)
                    print("Absolute file path: " + absolute_path)
                else:
                    printerr("File reported as saved but does not exist at: " + full_scene_path)
            else:
                print("Sprite loaded successfully with texture: " + full_texture_path)
        else:
            printerr("Failed to save scene: " + str(error))
    else:
        printerr("Failed to pack scene: " + str(result))

# Export a scene as a MeshLibrary resource
func export_mesh_library(params):
    print("Exporting MeshLibrary from scene: " + params.scene_path)
    
    # Ensure the scene path starts with res:// for Godot's resource system
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    
    if debug_mode:
        print("Full scene path (with res://): " + full_scene_path)
    
    # Ensure the output path starts with res:// for Godot's resource system
    var full_output_path = params.output_path
    if not full_output_path.begins_with("res://"):
        full_output_path = "res://" + full_output_path
    
    if debug_mode:
        print("Full output path (with res://): " + full_output_path)
    
    # Check if the scene file exists
    var file_check = FileAccess.file_exists(full_scene_path)
    if debug_mode:
        print("Scene file exists check: " + str(file_check))
    
    if not file_check:
        printerr("Scene file does not exist at: " + full_scene_path)
        # Get the absolute path for reference
        var absolute_path = ProjectSettings.globalize_path(full_scene_path)
        printerr("Absolute file path that doesn't exist: " + absolute_path)
        quit(1)
    
    # Load the scene
    if debug_mode:
        print("Loading scene from: " + full_scene_path)
    var scene = load(full_scene_path)
    if not scene:
        printerr("Failed to load scene: " + full_scene_path)
        quit(1)
    
    if debug_mode:
        print("Scene loaded successfully")
    
    # Instance the scene
    var scene_root = scene.instantiate()
    if debug_mode:
        print("Scene instantiated")
    
    # Create a new MeshLibrary
    var mesh_library = MeshLibrary.new()
    if debug_mode:
        print("Created new MeshLibrary")
    
    # Get mesh item names if provided
    var mesh_item_names = params.mesh_item_names if params.has("mesh_item_names") else []
    var use_specific_items = mesh_item_names.size() > 0
    
    if debug_mode:
        if use_specific_items:
            print("Using specific mesh items: " + str(mesh_item_names))
        else:
            print("Using all mesh items in the scene")
    
    # Process all child nodes
    var item_id = 0
    if debug_mode:
        print("Processing child nodes...")
    
    for child in scene_root.get_children():
        if debug_mode:
            print("Checking child node: " + child.name)
        
        # Skip if not using all items and this item is not in the list
        if use_specific_items and not (child.name in mesh_item_names):
            if debug_mode:
                print("Skipping node " + child.name + " (not in specified items list)")
            continue
            
        # Check if the child has a mesh
        var mesh_instance = null
        if child is MeshInstance3D:
            mesh_instance = child
            if debug_mode:
                print("Node " + child.name + " is a MeshInstance3D")
        else:
            # Try to find a MeshInstance3D in the child's descendants
            if debug_mode:
                print("Searching for MeshInstance3D in descendants of " + child.name)
            for descendant in child.get_children():
                if descendant is MeshInstance3D:
                    mesh_instance = descendant
                    if debug_mode:
                        print("Found MeshInstance3D in descendant: " + descendant.name)
                    break
        
        if mesh_instance and mesh_instance.mesh:
            if debug_mode:
                print("Adding mesh: " + child.name)
            
            # Add the mesh to the library
            mesh_library.create_item(item_id)
            mesh_library.set_item_name(item_id, child.name)
            mesh_library.set_item_mesh(item_id, mesh_instance.mesh)
            if debug_mode:
                print("Added mesh to library with ID: " + str(item_id))
            
            # Add collision shape if available
            var collision_added = false
            for collision_child in child.get_children():
                if collision_child is CollisionShape3D and collision_child.shape:
                    mesh_library.set_item_shapes(item_id, [collision_child.shape])
                    if debug_mode:
                        print("Added collision shape from: " + collision_child.name)
                    collision_added = true
                    break
            
            if debug_mode and not collision_added:
                print("No collision shape found for mesh: " + child.name)
            
            # Add preview if available
            if mesh_instance.mesh:
                mesh_library.set_item_preview(item_id, mesh_instance.mesh)
                if debug_mode:
                    print("Added preview for mesh: " + child.name)
            
            item_id += 1
        elif debug_mode:
            print("Node " + child.name + " has no valid mesh")
    
    if debug_mode:
        print("Processed " + str(item_id) + " meshes")
    
    # Create directory if it doesn't exist
    var dir = DirAccess.open("res://")
    if dir == null:
        printerr("Failed to open res:// directory")
        printerr("DirAccess error: " + str(DirAccess.get_open_error()))
        quit(1)
        
    var output_dir = full_output_path.get_base_dir()
    if debug_mode:
        print("Output directory: " + output_dir)
    
    if output_dir != "res://" and not dir.dir_exists(output_dir.substr(6)):  # Remove "res://" prefix
        if debug_mode:
            print("Creating directory: " + output_dir)
        var error = dir.make_dir_recursive(output_dir.substr(6))  # Remove "res://" prefix
        if error != OK:
            printerr("Failed to create directory: " + output_dir + ", error: " + str(error))
            quit(1)
    
    # Save the mesh library
    if item_id > 0:
        if debug_mode:
            print("Saving MeshLibrary to: " + full_output_path)
        var error = ResourceSaver.save(mesh_library, full_output_path)
        if debug_mode:
            print("Save result: " + str(error) + " (OK=" + str(OK) + ")")
        
        if error == OK:
            # Verify the file was actually created
            if debug_mode:
                var file_check_after = FileAccess.file_exists(full_output_path)
                print("File exists check after save: " + str(file_check_after))
                
                if file_check_after:
                    print("MeshLibrary exported successfully with " + str(item_id) + " items to: " + full_output_path)
                    # Get the absolute path for reference
                    var absolute_path = ProjectSettings.globalize_path(full_output_path)
                    print("Absolute file path: " + absolute_path)
                else:
                    printerr("File reported as saved but does not exist at: " + full_output_path)
            else:
                print("MeshLibrary exported successfully with " + str(item_id) + " items to: " + full_output_path)
        else:
            printerr("Failed to save MeshLibrary: " + str(error))
    else:
        printerr("No valid meshes found in the scene")

# Find files with a specific extension recursively
func find_files(path, extension):
    var files = []
    var dir = DirAccess.open(path)
    
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        
        while file_name != "":
            if dir.current_is_dir() and not file_name.begins_with("."):
                files.append_array(find_files(path + file_name + "/", extension))
            elif file_name.ends_with(extension):
                files.append(path + file_name)
            
            file_name = dir.get_next()
    
    return files

# Get UID for a specific file
func get_uid(params):
    if not params.has("file_path"):
        printerr("File path is required")
        quit(1)
    
    # Ensure the file path starts with res:// for Godot's resource system
    var file_path = params.file_path
    if not file_path.begins_with("res://"):
        file_path = "res://" + file_path
    
    print("Getting UID for file: " + file_path)
    if debug_mode:
        print("Full file path (with res://): " + file_path)
    
    # Get the absolute path for reference
    var absolute_path = ProjectSettings.globalize_path(file_path)
    if debug_mode:
        print("Absolute file path: " + absolute_path)
    
    # Ensure the file exists
    var file_check = FileAccess.file_exists(file_path)
    if debug_mode:
        print("File exists check: " + str(file_check))
    
    if not file_check:
        printerr("File does not exist at: " + file_path)
        printerr("Absolute file path that doesn't exist: " + absolute_path)
        quit(1)
    
    # Check if the UID file exists
    var uid_path = file_path + ".uid"
    if debug_mode:
        print("UID file path: " + uid_path)
    
    var uid_check = FileAccess.file_exists(uid_path)
    if debug_mode:
        print("UID file exists check: " + str(uid_check))
    
    # Ask Godot first: works for scenes/resources (UID in the file header)
    # and for scripts/shaders (UID in a .uid sidecar file).
    var uid_id = existing_uid(file_path)
    if uid_id != ResourceUID.INVALID_ID:
        print(JSON.stringify({
            "file": file_path,
            "absolutePath": absolute_path,
            "uid": ResourceUID.id_to_text(uid_id),
            "exists": true
        }))
        return

    var f = FileAccess.open(uid_path, FileAccess.READ)

    if f:
        # Read the UID content
        var uid_content = f.get_as_text()
        f.close()
        if debug_mode:
            print("UID content read successfully")
        
        # Return the UID content
        var result = {
            "file": file_path,
            "absolutePath": absolute_path,
            "uid": uid_content.strip_edges(),
            "exists": true
        }
        if debug_mode:
            print("UID result: " + JSON.stringify(result))
        print(JSON.stringify(result))
    else:
        if debug_mode:
            print("UID file does not exist or could not be opened")
        
        # UID file doesn't exist
        var result = {
            "file": file_path,
            "absolutePath": absolute_path,
            "exists": false,
            "message": "UID file does not exist for this file. Use resave_resources to generate UIDs."
        }
        if debug_mode:
            print("UID result: " + JSON.stringify(result))
        print(JSON.stringify(result))

# Read the uid="uid://..." from a text resource's first line (.tscn/.tres).
# ResourceLoader.get_resource_uid() relies on the editor's UID cache, which a
# headless --script run doesn't have, so read the header directly.
func read_header_uid(path: String) -> int:
    var f = FileAccess.open(path, FileAccess.READ)
    if not f:
        return ResourceUID.INVALID_ID
    var header = f.get_line()
    f.close()
    var re = RegEx.new()
    re.compile('uid="(uid://[^"]+)"')
    var m = re.search(header)
    if m:
        return ResourceUID.text_to_id(m.get_string(1))
    return ResourceUID.INVALID_ID

# The UID a file already has, from its header or its .uid sidecar (or INVALID_ID)
func existing_uid(path: String) -> int:
    var id = read_header_uid(path)
    if id != ResourceUID.INVALID_ID:
        return id
    if FileAccess.file_exists(path + ".uid"):
        var text = FileAccess.get_file_as_string(path + ".uid").strip_edges()
        if text.begins_with("uid://"):
            return ResourceUID.text_to_id(text)
    return ResourceLoader.get_resource_uid(path)

# Save a resource without losing the UID its file already had
func save_preserving_uid(resource: Resource, path: String) -> int:
    var old_id = existing_uid(path) if FileAccess.file_exists(path) else ResourceUID.INVALID_ID
    var err = ResourceSaver.save(resource, path)
    if err != OK:
        return err
    if old_id != ResourceUID.INVALID_ID:
        if read_header_uid(path) != old_id:
            ResourceSaver.set_uid(path, old_id)
    else:
        ensure_scene_uid(path)
    return OK

# Give a saved scene/resource a UID in its header if it has none. Returns true if one was added.
func ensure_scene_uid(path: String) -> bool:
    if read_header_uid(path) != ResourceUID.INVALID_ID:
        return false
    var id = ResourceUID.create_id()
    var err = ResourceSaver.set_uid(path, id)
    if err != OK:
        printerr("Failed to set UID for: " + path + ", error: " + str(err))
        return false
    ResourceUID.add_id(id, path)
    print("Generated UID for: " + path + " -> " + ResourceUID.id_to_text(id))
    return true

# Create the "<file>.uid" sidecar used by scripts and shaders (Godot 4.4+)
func write_uid_sidecar(path: String) -> int:
    var id = ResourceUID.create_id()
    var f = FileAccess.open(path + ".uid", FileAccess.WRITE)
    if not f:
        return FileAccess.get_open_error()
    f.store_string(ResourceUID.id_to_text(id) + "\n")
    f.close()
    print("Generated UID for: " + path + " -> " + ResourceUID.id_to_text(id))
    return OK

# Resave all resources to update UID references
func resave_resources(params):
    print("Resaving all resources to update UID references...")
    
    # Get project path if provided
    var project_path = "res://"
    # Only a project-relative subfolder makes sense here; an absolute OS path is the
    # project root itself (Godot was started with --path), so keep res://.
    if params.has("project_path") and not str(params.project_path).is_absolute_path():
        project_path = params.project_path
        if not project_path.begins_with("res://"):
            project_path = "res://" + project_path
        if not project_path.ends_with("/"):
            project_path += "/"
    
    if debug_mode:
        print("Using project path: " + project_path)
    
    # Get all .tscn files
    if debug_mode:
        print("Searching for scene files in: " + project_path)
    var scenes = find_files(project_path, ".tscn")
    if debug_mode:
        print("Found " + str(scenes.size()) + " scenes")
    
    # Resave each scene
    var success_count = 0
    var error_count = 0
    var missing_uids = 0
    var generated_uids = 0
    
    for scene_path in scenes:
        if debug_mode:
            print("Processing scene: " + scene_path)
        
        # Check if the scene file exists
        var file_check = FileAccess.file_exists(scene_path)
        if debug_mode:
            print("Scene file exists check: " + str(file_check))
        
        if not file_check:
            printerr("Scene file does not exist at: " + scene_path)
            error_count += 1
            continue
        
        # Load the scene
        var scene = load(scene_path)
        if scene:
            if debug_mode:
                print("Scene loaded successfully, saving...")
            var had_uid = read_header_uid(scene_path) != ResourceUID.INVALID_ID
            var error = save_preserving_uid(scene, scene_path)
            if debug_mode:
                print("Save result: " + str(error) + " (OK=" + str(OK) + ")")
            
            if error == OK:
                success_count += 1
                # Headless --script runs don't get UIDs from the editor's filesystem scan,
                # so give scenes without one a fresh UID explicitly.
                if not had_uid:
                    generated_uids += 1
                if debug_mode:
                    print("Scene saved successfully: " + scene_path)
                
                    # Verify the file was actually updated
                    var file_check_after = FileAccess.file_exists(scene_path)
                    print("File exists check after save: " + str(file_check_after))
                
                    if not file_check_after:
                        printerr("File reported as saved but does not exist at: " + scene_path)
            else:
                error_count += 1
                printerr("Failed to save: " + scene_path + ", error: " + str(error))
        else:
            error_count += 1
            printerr("Failed to load: " + scene_path)
    
    # Get all .gd and .shader files
    if debug_mode:
        print("Searching for script and shader files in: " + project_path)
    var scripts = find_files(project_path, ".gd") + find_files(project_path, ".shader") + find_files(project_path, ".gdshader")
    if debug_mode:
        print("Found " + str(scripts.size()) + " scripts/shaders")
    
    # Check for missing .uid files
    for script_path in scripts:
        if debug_mode:
            print("Checking UID for: " + script_path)
        var uid_path = script_path + ".uid"
        
        var uid_check = FileAccess.file_exists(uid_path)
        if debug_mode:
            print("UID file exists check: " + str(uid_check))
        
        var f = FileAccess.open(uid_path, FileAccess.READ)
        if not f:
            missing_uids += 1
            if debug_mode:
                print("Missing UID file for: " + script_path + ", generating...")
            
            # Write the .uid sidecar ourselves; ResourceSaver.save doesn't create
            # one when the editor filesystem isn't running (headless --script).
            var res = load(script_path)
            if res:
                var error = write_uid_sidecar(script_path)
                if debug_mode:
                    print("Save result: " + str(error) + " (OK=" + str(OK) + ")")
                
                if error == OK:
                    generated_uids += 1
                    if debug_mode:
                        print("Generated UID for: " + script_path)
                    
                        # Verify the UID file was actually created
                        var uid_check_after = FileAccess.file_exists(uid_path)
                        print("UID file exists check after save: " + str(uid_check_after))
                    
                        if not uid_check_after:
                            printerr("UID file reported as generated but does not exist at: " + uid_path)
                else:
                    printerr("Failed to generate UID for: " + script_path + ", error: " + str(error))
            else:
                printerr("Failed to load resource: " + script_path)
        elif debug_mode:
            print("UID file already exists for: " + script_path)
    
    if debug_mode:
        print("Summary:")
        print("- Scenes processed: " + str(scenes.size()))
        print("- Scenes successfully saved: " + str(success_count))
        print("- Scenes with errors: " + str(error_count))
        print("- Scripts/shaders missing UIDs: " + str(missing_uids))
        print("- UIDs successfully generated: " + str(generated_uids))
    print("Resave operation complete")

# Save changes to a scene file
func save_scene(params):
    print("Saving scene: " + params.scene_path)
    
    # Ensure the scene path starts with res:// for Godot's resource system
    var full_scene_path = params.scene_path
    if not full_scene_path.begins_with("res://"):
        full_scene_path = "res://" + full_scene_path
    
    if debug_mode:
        print("Full scene path (with res://): " + full_scene_path)
    
    # Check if the scene file exists
    var file_check = FileAccess.file_exists(full_scene_path)
    if debug_mode:
        print("Scene file exists check: " + str(file_check))
    
    if not file_check:
        printerr("Scene file does not exist at: " + full_scene_path)
        # Get the absolute path for reference
        var absolute_path = ProjectSettings.globalize_path(full_scene_path)
        printerr("Absolute file path that doesn't exist: " + absolute_path)
        quit(1)
    
    # Load the scene
    var scene = load(full_scene_path)
    if not scene:
        printerr("Failed to load scene: " + full_scene_path)
        quit(1)
    
    if debug_mode:
        print("Scene loaded successfully")
    
    # Instance the scene
    var scene_root = scene.instantiate()
    if debug_mode:
        print("Scene instantiated")
    
    # Determine save path
    var save_path = params.new_path if params.has("new_path") else full_scene_path
    if params.has("new_path") and not save_path.begins_with("res://"):
        save_path = "res://" + save_path
    
    if debug_mode:
        print("Save path: " + save_path)
    
    # Create directory if it doesn't exist
    if params.has("new_path"):
        var dir = DirAccess.open("res://")
        if dir == null:
            printerr("Failed to open res:// directory")
            printerr("DirAccess error: " + str(DirAccess.get_open_error()))
            quit(1)
            
        var scene_dir = save_path.get_base_dir()
        if debug_mode:
            print("Scene directory: " + scene_dir)
        
        if scene_dir != "res://" and not dir.dir_exists(scene_dir.substr(6)):  # Remove "res://" prefix
            if debug_mode:
                print("Creating directory: " + scene_dir)
            var error = dir.make_dir_recursive(scene_dir.substr(6))  # Remove "res://" prefix
            if error != OK:
                printerr("Failed to create directory: " + scene_dir + ", error: " + str(error))
                quit(1)
    
    # Create a packed scene
    var packed_scene = PackedScene.new()
    var result = packed_scene.pack(scene_root)
    if debug_mode:
        print("Pack result: " + str(result) + " (OK=" + str(OK) + ")")
    
    if result == OK:
        if debug_mode:
            print("Saving scene to: " + save_path)
        var error = save_preserving_uid(packed_scene, save_path)
        if debug_mode:
            print("Save result: " + str(error) + " (OK=" + str(OK) + ")")
        
        if error == OK:
            # Verify the file was actually created/updated
            if debug_mode:
                var file_check_after = FileAccess.file_exists(save_path)
                print("File exists check after save: " + str(file_check_after))
                
                if file_check_after:
                    print("Scene saved successfully to: " + save_path)
                    # Get the absolute path for reference
                    var absolute_path = ProjectSettings.globalize_path(save_path)
                    print("Absolute file path: " + absolute_path)
                else:
                    printerr("File reported as saved but does not exist at: " + save_path)
            else:
                print("Scene saved successfully to: " + save_path)
        else:
            printerr("Failed to save scene: " + str(error))
    else:
        printerr("Failed to pack scene: " + str(result))

# ---------------------------------------------------------------------------
# Structured results
#
# Newer operations print exactly one "MCP_RESULT:<json>" line on success, or
# "MCP_ERROR:<message>" lines on stderr on failure, so the server can parse
# results reliably instead of scraping log text.
# ---------------------------------------------------------------------------

func emit_result(data) -> void:
    print("MCP_RESULT:" + JSON.stringify(data))

func fail(message: String) -> void:
    printerr("MCP_ERROR:" + message)
    has_failed = true
    quit(1)

func to_res_path(path: String) -> String:
    return path if path.begins_with("res://") else "res://" + path

# Load and instantiate a scene; returns null (after reporting) on failure
func open_scene(scene_path: String) -> Node:
    var res_path = to_res_path(scene_path)
    if not FileAccess.file_exists(res_path):
        fail("Scene does not exist: " + res_path)
        return null
    var packed = load(res_path) as PackedScene
    if packed == null:
        fail("Not a loadable scene: " + res_path)
        return null
    var root = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
    if root == null:
        fail("Could not instantiate scene: " + res_path)
    return root

# Pack and save a scene back to its file, keeping its UID
func store_scene(root: Node, scene_path: String) -> bool:
    var packed = PackedScene.new()
    var err = packed.pack(root)
    if err != OK:
        fail("Failed to pack scene: " + error_string(err))
        return false
    err = save_preserving_uid(packed, to_res_path(scene_path))
    if err != OK:
        fail("Failed to save scene: " + error_string(err))
        return false
    return true

# Find a node by path relative to the scene root. "", "." and "root" mean the root;
# a leading "root/" or the root's own name is accepted too.
func find_scene_node(root: Node, node_path: String) -> Node:
    var p = node_path.strip_edges()
    if p == "" or p == "." or p == "root" or p == String(root.name):
        return root
    if p.begins_with("root/"):
        p = p.substr(5)
    elif p.begins_with(String(root.name) + "/"):
        p = p.substr(String(root.name).length() + 1)
    return root.get_node_or_null(NodePath(p))

# Make a value JSON-friendly; Godot types become their GDScript literal text
func describe_value(value):
    match typeof(value):
        TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
            return value
        TYPE_FLOAT:
            return value if is_finite(value) else str(value)
        TYPE_STRING_NAME, TYPE_NODE_PATH:
            return str(value)
        TYPE_OBJECT:
            if value == null:
                return null
            if value is Resource:
                if value.resource_path != "" and not value.resource_path.contains("::"):
                    return value.resource_path
                return "<" + value.get_class() + ">"
            return "<" + value.get_class() + ">"
        _:
            var text = var_to_str(value)
            return text if text.length() <= 300 else text.substr(0, 300) + "..."

# Properties that differ from the class default (what the editor would save)
func changed_properties(node: Node) -> Dictionary:
    var out = {}
    var cls = node.get_class()
    for prop in node.get_property_list():
        var usage = prop["usage"]
        if not (usage & PROPERTY_USAGE_STORAGE) or (usage & PROPERTY_USAGE_INTERNAL):
            continue
        var name = prop["name"]
        if name in ["script", "owner", "unique_name_in_owner"] or name.begins_with("metadata/"):
            continue
        var value = node.get(name)
        if ClassDB.class_exists(cls):
            var default_value = ClassDB.class_get_property_default_value(cls, name)
            if typeof(default_value) == typeof(value) and default_value == value:
                continue
            if default_value == null and value == null:
                continue
        out[name] = describe_value(value)
    return out

func describe_node(node: Node, root: Node, include_properties: bool, depth: int, max_depth: int) -> Dictionary:
    var info = {
        "name": String(node.name),
        "type": node.get_class(),
        "path": "." if node == root else str(root.get_path_to(node)),
    }
    var script = node.get_script()
    if script:
        info["script"] = script.resource_path
    if node != root and node.scene_file_path != "":
        info["instance_of"] = node.scene_file_path
    var groups = []
    for g in node.get_groups():
        if not String(g).begins_with("_"):
            groups.append(String(g))
    if groups.size() > 0:
        info["groups"] = groups
    if include_properties:
        var props = changed_properties(node)
        if props.size() > 0:
            info["properties"] = props
    var children = []
    # Don't descend into instanced sub-scenes; their insides live in their own file
    if (node == root or node.scene_file_path == "") and (max_depth < 0 or depth < max_depth):
        for child in node.get_children():
            if child.owner == root or child.owner == null:
                children.append(describe_node(child, root, include_properties, depth + 1, max_depth))
    if children.size() > 0:
        info["children"] = children
    return info

# Read a scene's node tree
func get_scene_tree(params):
    if not params.has("scene_path"):
        fail("scene_path is required")
        return
    var root = open_scene(params.scene_path)
    if root == null:
        return
    var start = root
    if params.has("node_path") and str(params.node_path) != "":
        start = find_scene_node(root, str(params.node_path))
        if start == null:
            fail("Node not found: " + str(params.node_path))
            return
    var include_properties = params.get("include_properties", true)
    var max_depth = int(params.get("max_depth", -1))
    var tree = describe_node(start, root, include_properties, 0, max_depth)
    if start != root:
        tree["path"] = str(root.get_path_to(start))
    emit_result(tree)
    root.free()

# Turn a JSON value into what the property expects, using the property's current type:
#   "res://..."            -> loaded resource
#   [x, y] / {"x":..}      -> Vector2/Vector3/Color/... when the property is one
#   "Vector2(1, 2)" etc.   -> parsed as a GDScript literal (str_to_var)
func coerce_value(current, value):
    var target = typeof(current)
    if typeof(value) == TYPE_STRING:
        var s: String = value
        if s.begins_with("res://") or s.begins_with("uid://"):
            if not ResourceLoader.exists(s):
                if FileAccess.file_exists(s):
                    return [false, "Resource not imported yet: " + s + " (open the project in the editor once)"]
                return [false, "Resource not found: " + s]
            return [true, load(s)]
        if target == TYPE_STRING or target == TYPE_STRING_NAME:
            return [true, s]
        if target == TYPE_NODE_PATH:
            return [true, NodePath(s)]
        if target == TYPE_COLOR and (s.begins_with("#") or Color.html_is_valid(s)):
            return [true, Color.html(s)]
        if target == TYPE_COLOR and not s.contains("("):
            return [true, Color.from_string(s, Color.BLACK)]
        var parsed = str_to_var(s)
        if parsed != null:
            return [true, parsed]
        return [true, s]
    if typeof(value) == TYPE_ARRAY:
        var a: Array = value
        match target:
            TYPE_VECTOR2:
                return [true, Vector2(a[0], a[1])]
            TYPE_VECTOR2I:
                return [true, Vector2i(a[0], a[1])]
            TYPE_VECTOR3:
                return [true, Vector3(a[0], a[1], a[2])]
            TYPE_VECTOR3I:
                return [true, Vector3i(a[0], a[1], a[2])]
            TYPE_VECTOR4:
                return [true, Vector4(a[0], a[1], a[2], a[3])]
            TYPE_COLOR:
                return [true, Color(a[0], a[1], a[2], a[3] if a.size() > 3 else 1.0)]
            TYPE_RECT2:
                return [true, Rect2(a[0], a[1], a[2], a[3])]
    if typeof(value) == TYPE_DICTIONARY:
        var d: Dictionary = value
        match target:
            TYPE_VECTOR2:
                return [true, Vector2(d.get("x", 0), d.get("y", 0))]
            TYPE_VECTOR2I:
                return [true, Vector2i(d.get("x", 0), d.get("y", 0))]
            TYPE_VECTOR3:
                return [true, Vector3(d.get("x", 0), d.get("y", 0), d.get("z", 0))]
            TYPE_COLOR:
                return [true, Color(d.get("r", 0), d.get("g", 0), d.get("b", 0), d.get("a", 1))]
    if typeof(value) == TYPE_FLOAT and target == TYPE_INT:
        return [true, int(value)]
    return [true, value]

func has_property(node: Object, name: String) -> bool:
    for prop in node.get_property_list():
        if prop["name"] == name:
            return true
    return false

# Set one or more properties on a node in a scene
func set_node_properties(params):
    if not params.has("scene_path") or not params.has("properties"):
        fail("scene_path and properties are required")
        return
    var root = open_scene(params.scene_path)
    if root == null:
        return
    var node = find_scene_node(root, str(params.get("node_path", ".")))
    if node == null:
        fail("Node not found: " + str(params.get("node_path", ".")))
        return
    var props = params.properties
    if typeof(props) == TYPE_STRING:
        props = JSON.parse_string(props)
    if typeof(props) != TYPE_DICTIONARY:
        fail("properties must be an object of name -> value")
        return
    var applied = {}
    var errors = []
    for name in props:
        if name == "script":
            errors.append("Use attach_script to set scripts")
            continue
        if not has_property(node, name):
            errors.append("'" + name + "' is not a property of " + node.get_class())
            continue
        var coerced = coerce_value(node.get(name), props[name])
        if not coerced[0]:
            errors.append(name + ": " + coerced[1])
            continue
        node.set(name, coerced[1])
        applied[name] = describe_value(node.get(name))
    if errors.size() > 0:
        root.free()
        fail("No changes saved. " + "; ".join(errors))
        return
    if store_scene(root, params.scene_path):
        emit_result({"node": "." if node == root else str(root.get_path_to(node)), "applied": applied})
    root.free()

const SCRIPT_TEMPLATE = "extends %s\n\n\nfunc _ready() -> void:\n\tpass\n\n\nfunc _process(delta: float) -> void:\n\tpass\n"

# Attach a script to a node, creating the script file if needed
func attach_script(params):
    if not params.has("scene_path") or not params.has("script_path"):
        fail("scene_path and script_path are required")
        return
    var script_path = to_res_path(str(params.script_path))
    if not script_path.ends_with(".gd"):
        fail("script_path must be a .gd file")
        return
    var root = open_scene(params.scene_path)
    if root == null:
        return
    var node = find_scene_node(root, str(params.get("node_path", ".")))
    if node == null:
        fail("Node not found: " + str(params.get("node_path", ".")))
        return

    var created = false
    var content = str(params.get("script_content", ""))
    if content != "" or not FileAccess.file_exists(script_path):
        if content == "":
            content = SCRIPT_TEMPLATE % node.get_class()
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(script_path.get_base_dir()))
        var f = FileAccess.open(script_path, FileAccess.WRITE)
        if f == null:
            fail("Cannot write script: " + script_path + " (" + error_string(FileAccess.get_open_error()) + ")")
            return
        f.store_string(content)
        f.close()
        created = true
        if not FileAccess.file_exists(script_path + ".uid"):
            write_uid_sidecar(script_path)

    var script = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
    if script == null or not script.can_instantiate():
        root.free()
        fail("Script has errors, not attached: " + script_path + " (run validate_scripts for details)")
        return
    var base = script.get_instance_base_type()
    if not ClassDB.is_parent_class(node.get_class(), base):
        var message = "Script extends " + str(base) + " but node '" + String(node.name) + "' is a " + node.get_class()
        root.free()
        fail(message)
        return
    node.set_script(script)
    if store_scene(root, params.scene_path):
        emit_result({
            "node": "." if node == root else str(root.get_path_to(node)),
            "script": script_path,
            "created": created,
        })
    root.free()

# Check scripts for parse/compile errors. Error details go to stderr (Godot prints
# "SCRIPT ERROR: ..." / "at: ... (res://file.gd:LINE)"); the server matches them up.
func validate_scripts(params):
    var paths = []
    if params.has("script_paths") and typeof(params.script_paths) == TYPE_ARRAY and params.script_paths.size() > 0:
        for p in params.script_paths:
            paths.append(to_res_path(str(p)))
    else:
        paths = find_files("res://", ".gd")
    var results = []
    for path in paths:
        if path.begins_with("res://addons/") and not params.get("include_addons", false):
            continue
        if not FileAccess.file_exists(path):
            results.append({"path": path, "ok": false, "missing": true})
            continue
        print("MCP_CHECKING:" + path)
        var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
        results.append({"path": path, "ok": script != null and script.can_instantiate()})
    emit_result(results)
