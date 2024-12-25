# Order of operations

## Certmanager

Has to be installed so that bitwarden secrets can communicate with external secrets

## External-Secrets

I think this is how I'm going to get all the secrets I need in for argo

This install won't create a `SecretStore` or `ExternalSecret` since
I want those created in the argo namespace so I'll set them up with argo.

## Argo

The last piece before I can do everything else all gitOps style.
