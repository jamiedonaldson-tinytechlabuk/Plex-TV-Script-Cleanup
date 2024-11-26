## Plex TV Show Cleanup Script

# Overview
This script is designed to help manage and clean up TV show folders in a Plex server environment. It started as an effort to reduce the size of a growing TV show directory that was filled with outdated or unwatched content. Over time, content accumulated in TBs and required regular cleaning to remove shows that were no longer being watched. The script leverages Tautulli (a Plex monitoring tool) to track which TV shows were recently watched and applies custom cleanup rules to maintain a manageable library size.

The script was initially based on the Sonarr Throttling Plugin for Organizr, which can be found here: Sonarr Throttling Plugin for Organizr.
https://github.com/TehMuffinMoo/Organizr-Plugins

# Features
* Exclusion Folders: A list of folders that will never be touched by the cleanup process, regardless of whether they are watched or not. This helps prevent accidental deletions of important folders.
* Tautulli Integration: Utilizes Tautulli API to determine which TV shows have been watched recently. Shows watched within the last specified number of months are not cleaned up.
* Folder-Level Cleanup Prompt: Option to prompt for folder-level deletion. The script will ask if the user wants to delete files within a folder that exceeds a certain number of episodes.
* Report-Only Mode: Option to run the script in report-only mode, where no files are deleted. Instead, the script will only show what would be deleted, useful for testing.
* Selective Deletion: Only deletes files within a folder that exceed the specified number of episodes (i.e., it keeps the most recent N episodes).
* Size and Count Reporting: Outputs the total number of files deleted and the space freed in GB or TB. It also provides reports on skipped folders, including their size.

# How It Works
The script works by scanning a defined root folder (e.g., where your Plex TV shows are stored). It then checks each subfolder (representing a TV show) against several criteria:

* Exclusion List: If the folder matches one of the exclusion folders, it is skipped.
* Tautulli Watch History: If the folder matches a show that has been watched recently (within a specified number of months), it is skipped.
* File Count and Size: If the folder has more files than the specified number to keep (e.g., the most recent 3 episodes), the script will ask for confirmation to clean up the excess files.
