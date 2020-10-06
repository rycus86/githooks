# Deprecated stuff

1. registered file becomse a JSON file -> legacy transform
2. Ignore patterns matched only filename. Now , ignore patterns are matching the paths relative to the

    - Git dir. for old hook `hooks/pre-commit.replaced.githooks`
    - `.githooks/<namespace>/` for shared hooks with a `.githooks` folder
    - `<namespace>/` for shared hooks without a `.githooks` folder.

Namespace `<namespace>` can be defined in shared hooks in a file `.namespace`. Default is empty.
3. TODO: `githooks.trust.all` move to `githooks.trustAll`
