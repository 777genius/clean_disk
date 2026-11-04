# Managed ReviewRouter installation

Code review is dispatched by the ReviewRouter GitHub App through
`.github/workflows/reviewrouter-review.yml`. Provider and model selection live
in ReviewRouter settings; this caller does not restore OAuth credentials.

The retired `reviewrouter-codex.yml` refresh workflow is not required.
The old interaction workflow is also retired; discussion handling remains off
until the deployment has a qualified Gateway interaction profile.
