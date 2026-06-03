---
name: spotify-playback
description: Control Spotify playback, manage playlists, and view track information with full remote control capabilities
version: 1.0.0
author: NeurX Team
maintainer: NeurX Team
category: integration
license: MIT
deprecated: false

platforms: [macos, linux, windows]
tags: [spotify, music, audio, media-control]
keywords: [spotify, playback, playlist, track, remote-control]

required_environment_variables:
  - name: SPOTIFY_CLIENT_ID
    prompt: "Enter your Spotify Client ID"
    help: "Get from https://developer.spotify.com/dashboard/applications"
    required: true
    secret: false
  
  - name: SPOTIFY_CLIENT_SECRET
    prompt: "Enter your Spotify Client Secret"
    help: "Available in the same Developer Dashboard application"
    required: true
    secret: true
  
  - name: SPOTIFY_REDIRECT_URI
    prompt: "Enter your Spotify Redirect URI (default: http://localhost:8888/callback)"
    help: "Must match URI configured in Developer Dashboard"
    required: false
    defaultValue: "http://localhost:8888/callback"

prerequisites:
  - type: command
    name: curl
    checkCommand: "curl --version"
    installCommand: "brew install curl  # macOS, or apt-get install curl on Linux"
  
  - type: command
    name: jq
    checkCommand: "jq --version"
    installCommand: "brew install jq  # macOS, or apt-get install jq on Linux"

related_skills:
  - audio-settings
  - music-library-search
  - playlist-management

hermes_metadata:
  tags:
    - tier: integration
    - usage: frequent
  related_skills:
    - music-search
    - audio-settings
---

# Spotify Playback Control Skill

This skill enables remote control of Spotify playback with full media management capabilities. Control playback state, manage volume, queue tracks, and retrieve information about currently playing content.

## Overview

The Spotify Playback skill provides a comprehensive interface to Spotify's Web API, allowing you to:

- **Playback Control**: Play, pause, skip, and manage playback state
- **Volume Management**: Adjust speaker volume and mute/unmute
- **Track Management**: Queue tracks, add to playlist, and get track info
- **Playlist Operations**: Browse playlists, create, and modify
- **Device Management**: Switch between available Spotify devices
- **Library Management**: Save/unsave tracks and manage favorites

## Authentication Setup

The skill uses OAuth2 authentication with Spotify:

1. Create a Spotify Developer Account at https://developer.spotify.com
2. Create an Application in your Dashboard
3. Copy `Client ID` and `Client Secret`
4. Set Redirect URI to match the `SPOTIFY_REDIRECT_URI` environment variable
5. Provide credentials when first initializing the skill

The skill will handle token refresh automatically.

## Usage Examples

### Get Currently Playing Track

```bash
skill exec spotify-playback -- current-track
```

**Output:**
```json
{
  "track": "Shape of You",
  "artist": "Ed Sheeran",
  "album": "÷",
  "duration_ms": 236000,
  "progress_ms": 45000,
  "is_playing": true
}
```

### Control Playback

Play current track:
```bash
skill exec spotify-playback -- play
```

Pause playback:
```bash
skill exec spotify-playback -- pause
```

Skip to next track:
```bash
skill exec spotify-playback -- next
```

Previous track:
```bash
skill exec spotify-playback -- previous
```

### Queue a Track

```bash
skill exec spotify-playback -- queue "spotify:track:3n3Ppam7vgaVa1iaRUc9Lp"
```

### Switch Device

List available devices:
```bash
skill exec spotify-playback -- list-devices
```

Switch to specific device:
```bash
skill exec spotify-playback -- set-device "Living Room Speaker"
```

### Volume Control

Adjust volume (0-100):
```bash
skill exec spotify-playback -- volume 75
```

## Advanced Usage

### Search and Play

```bash
skill exec spotify-playback -- search-and-play "Bohemian Rhapsody"
```

Searches for the track and plays it on the active device.

### Create Playlist and Add Tracks

```bash
skill exec spotify-playback -- create-playlist "Workout Mix"
skill exec spotify-playback -- add-to-playlist "Workout Mix" "Energy" 5
```

### Get Recommendations

Based on currently playing track:
```bash
skill exec spotify-playback -- get-recommendations --limit 10
```

## Common Workflows

### Morning Routine

```bash
skill exec spotify-playback -- set-device "Kitchen Speaker"
skill exec spotify-playback -- search-and-play "Good Morning Mix"
skill exec spotify-playback -- volume 50
```

### Party Mode

```bash
skill exec spotify-playback -- create-playlist "Party Time"
skill exec spotify-playback -- queue "danceability:high" --limit 20
skill exec spotify-playback -- set-device "Living Room"
skill exec spotify-playback -- volume 100
```

## Edge Cases & Error Handling

### No Active Device
If no Spotify client is running:
```
Error: No active device found
Solution: Open Spotify on a device or specify --device parameter
```

### Token Expiration
The skill automatically refreshes OAuth tokens. If you get:
```
Error: Invalid token
Solution: Re-authenticate by providing credentials again
```

### Rate Limiting
Spotify API has rate limits. If you get:
```
Error: Rate limit exceeded
Solution: Wait 30 seconds before retrying
```

### Specific Track Not Found
If a track cannot be played:
```
Error: Track not available in your region
Solution: Search for alternatives or check streaming availability
```

## Integration with Other Skills

### With `music-library-search` skill
Combine for advanced music discovery:
```bash
skill exec music-library-search -- find-by-genre "electronic"
skill exec spotify-playback -- queue <returned-track-ids>
```

### With `audio-settings` skill
Combine for complete audio environment control:
```bash
skill exec audio-settings -- set-output "HDMI"
skill exec spotify-playback -- play
```

## Permissions & Privacy

This skill:
- ✅ Requires explicit user authorization via OAuth2
- ✅ Does NOT store authentication credentials (only tokens)
- ✅ Does NOT log listening history
- ✅ Respects user's playback privacy settings

All API calls are made to official Spotify servers. No third-party analytics or tracking.

## Troubleshooting

### "Connection refused" error
- Ensure you have internet connectivity
- Verify Spotify API endpoint is accessible (not blocked by firewall)
- Check your network proxy settings if behind corporate firewall

### "Invalid credentials" error
- Verify `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET` are correct
- Check if application is enabled in Developer Dashboard
- Try re-authenticating with fresh credentials

### Skill not responding
- Check if Spotify is running on at least one device
- Verify device is selected: `skill exec spotify-playback -- list-devices`
- Check skill logs: `cat ~/.hermes/logs/spotify-playback.log`

### Commands taking too long
- Spotify API timeout is 30 seconds
- If consistently timing out, check internet connection
- Try reducing batch operations (queue many tracks at once)

## Performance Notes

- **Current track info**: ~100ms response time
- **Search**: ~200-500ms depending on query
- **Playlist operations**: ~150-300ms
- **Device switching**: ~50ms

For batch operations, consider grouping commands to minimize API calls.

## Support & Feedback

- Report bugs: https://github.com/neurx/skills/issues
- Documentation: https://neurx.dev/skills/spotify
- Community: https://discord.gg/neurx

## Changelog

### v1.0.0 (2024-06-03)
- Initial release
- Basic playback control
- Playlist management
- Device switching
- OAuth2 authentication

## See Also

- [Spotify Web API Docs](https://developer.spotify.com/documentation/web-api)
- [NeurX Skills System](https://neurx.dev/docs/skills)
- [Audio Control Guide](https://neurx.dev/guides/audio)
