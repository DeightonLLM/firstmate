# Core-Distro WordPress port — deployable artifact

**Revision:** `50ae6849c190`
**Theme version:** `1.1.0`
**Parent theme required:** Astra 4.14.0 (WordPress.org, free)
**Child theme directory:** `core-distro-astra-child/`
**Files:** 19
**Integrity manifest sha256:** `50ae6849c190654b4e448125b717e77004e3d5cc8f22a254973ad3cb2ecb99b7`

## What this is

The tested WordPress port of live core-distro.com: an Astra child theme plus the
generated homepage body and public stylesheet. It is the build that scored 10/10
on its test suite with all 12 intended routes returning HTTP 200 on the private
origin.

## Verify before deploying

```
cd /home/hd2admin/kun-agent-workspace/data/core-staging-publish-20261014/artifact
sha256sum -c SHA256SUMS
```

Every line must report `OK`. A mismatch means the artifact is not the tested one
and must not be deployed.

## Deploy

1. Install WordPress plus the Astra 4.14.0 parent theme.
2. Copy `core-distro-astra-child/` to `wp-content/themes/core-distro-astra-child/`.
3. Activate `core-distro-astra-child` as the active theme.
4. Verify the 12 intended routes, then confirm the chatbot.

## Honest scope of this artifact

- It is **not** a database export. Page records and the menu must exist in the
  target install; the theme alone does not create them.
- The chatbot is **not activated** in this build. Captain's acceptance requires a
  working chatbot, so that remains outstanding.
- The newsletter form is intentionally inert. Do not enable it against live.
- Nine duplicate seed page records were previously present and were drafted, not
  deleted. Check the target install for duplicates before importing content.

## Provenance

Built from `/home/hd2admin/campaign/core-distro-stage/theme`
Revision is content-addressed: the same source always produces `50ae6849c190`.
