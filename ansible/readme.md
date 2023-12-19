# Ansible notes

## To encrypt stuff

I always forget this:

```bash
ansible-vault encrypt --vault-password-file vault_password --encrypt-vault-id default <your file or files>
```

If you don't have `vault_password` in the repo it's in a note in Bitwarden.
