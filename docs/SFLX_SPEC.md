# Mornye `.sflx` Extension Specification (v1.0)

Nami's built-in **Mornye** engine loads music metadata, streaming, and lossless download extensions from standalone `.sflx` JSON files, remote URLs, or `.zip` extension bundles.

---

## 1. Single Provider Manifest (`.sflx`)

```json
{
  "id": "custom_lossless_provider",
  "name": "Custom Lossless Feed",
  "version": "v1.0.0",
  "author": "YourHandle",
  "category": "Download",
  "format": "24B / 192kHz FLAC",
  "description": "Resolves studio master FLAC streams for Mornye.",
  "endpointUrl": "https://api.example.com/v1/resolve"
}
```

### Field Reference

| Field | Required | Type | Description |
| :--- | :---: | :---: | :--- |
| `name` | Yes | `string` | Display name shown in Mornye Repo and service chips. |
| `id` | No | `string` | Stable lowercase identifier; auto-generated from `name` if omitted. |
| `version` | No | `string` | Semantic version string (e.g. `v1.2.0`). |
| `author` | No | `string` | Creator or community maintainer name. |
| `category` | No | `string` | One of `Download`, `Metadata`, or `Utility`. |
| `format` | No | `string` | Audio format badge (e.g. `24B FLAC`, `16B FLAC`, `ALAC`, `Synced .LRC`). |
| `description` | No | `string` | Short summary displayed in Mornye Repo. |
| `endpointUrl` | No | `string` | Resolver endpoint URL. If omitted, Mornye uses public catalog 30s previews. |

---

## 2. Stream Resolver Contract (`endpointUrl`)

When a user streams or downloads a track, Mornye sends a `GET` request to `endpointUrl` with query parameters:

```text
GET {endpointUrl}?title=<URL_ENCODED_TITLE>&artist=<URL_ENCODED_ARTIST>&album=<URL_ENCODED_ALBUM>
```

Your endpoint may respond with **either**:
1. Plain text containing a direct `https://...` audio URL, **or**
2. A JSON object containing any of: `streamUrl`, `downloadUrl`, `flacUrl`, `audioUrl`, `trackUrl`, or `url`.

```json
{
  "streamUrl": "https://cdn.example.com/tracks/sample_24bit.flac",
  "format": "FLAC",
  "bitDepth": 24,
  "sampleRate": 96000
}
```

---

## 3. Repository Index Format (`repo_index.json` / `.sflx`)

You can distribute multiple providers in a single file or URL using an `extensions` array:

```json
{
  "repoName": "Community Hi-Res Repo",
  "extensions": [
    {
      "name": "Example FLAC Feed",
      "version": "v1.0.0",
      "author": "Community",
      "category": "Download",
      "format": "24B FLAC",
      "description": "High-resolution audio resolver.",
      "endpointUrl": "https://api.example.com/resolve"
    }
  ]
}
```

---

## 4. ZIP Bundle Format (`.zip`)

Any `.zip` archive containing one or more `.sflx`, `.json`, or `*manifest*` files is automatically unpacked in memory by Nami's built-in ZIP reader via **Mornye -> Repo -> Import .sflx / ZIP** or **Add from URL**.
