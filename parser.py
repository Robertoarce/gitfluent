import os
import shutil

def flatten_directory(root_dir):
    # Get the absolute path of the root directory
    root_dir = os.path.abspath(root_dir)
    
    # Walk through the directory tree
    for dirpath, dirnames, filenames in os.walk(root_dir, topdown=False):
        for filename in filenames:
            # Get the full path of the file
            file_path = os.path.join(dirpath, filename)
            git
            # Check if the file has .yml or .py extension
            if filename.endswith(('.yml', '.py')):
                # Create the new filename
                rel_path = os.path.relpath(file_path, root_dir)
                new_filename = rel_path.replace(os.path.sep, '-')
                
                # Move and rename the file
                shutil.move(file_path, os.path.join(root_dir, new_filename))
            else:
                # Delete files that are not .yml or .py
                os.remove(file_path)
    
    # Remove empty directories
    for dirpath, dirnames, filenames in os.walk(root_dir, topdown=False):
        if dirpath != root_dir:
            try:
                os.rmdir(dirpath)
            except OSError:
                pass

# Get the root directory from the user
root_dir = input("Enter the path of the directory to flatten: ")

# Call the function to flatten the directory
flatten_directory(root_dir)

print(f"Directory {root_dir} has been flattened. Only .yml and .py files have been kept, using '-' as a separator.")