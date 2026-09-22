My basic Idea here that I will flesh out more as I go and as I use it is there will be 3 things under this directory.

1. A basic controller script my idea is that you would declare:
	- host
	- user
	- database (optional)
	- path_to_file
	- path_to_output
	- additional arguments...
2. A directory for primary
	- Only querys that should be run on the primary go here
3. A directory for secondary
	- Only querys that should be run on a secondary go here
4. A directory for any
	- Queries that can/should be run on either the primary or secondary go here
