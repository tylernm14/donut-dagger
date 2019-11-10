## TODO - things to consider adding

- Restart jobs if whole cluster of stateless machines is restarted
- Freeze workflows after some timeout
- Redo _row and _row_jobs partials to be more meaningful
- Reap stray kube jobs at some interval
- On job completion consider zipping output to s3 and deleting workflow dir
