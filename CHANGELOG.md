# Changes


## v0.1.0

* docs: update example
* docs: upgrade example for k8s 1.16+
* chore: log cleanup
* docs: update credits section
* chore: revert to hacker theme
* feat: add link
* chore: try tactile
* chore: try a different theme
* chore: add newline to generated file
* Set theme jekyll-theme-minimal
* feat: add working_dir option
* chore: merge in upstream so those commits aren't lost
* chore(makefile): add uninstall, remove phony from install
* docs: note about verifying contents
* docs: cleanup, reorganize, inline examples
* feat: hpas work!
* feat: hpa
* chore: more logging
* feat: add ON_FAILURE hook
* chore: change some variable names
* fix: 2>&1, also docs
* feat: more validation
* docs: note about hpa status
* docs: example and readme cleanup
* fix: custom healthcheck works now
* docs(example): cleanup
* docs: note about gsed
* fix(makefile): add PHONY
* feat: add tests
* chore: remove test file
* chore: clean up misc project files
* chore: remove working_dir option, always use mktemp -d
* chore: remove input_deployment option
* fix: only gnu sed
* fix: disable deleting hpas until backing up works
* docs: add example
* fix: more validation
* fix: remove broken release script

## v0.0.1

* docs: links, better help, etc
* chore: local variables should be lowercase, and better names
* chore: remove gross let style math expressions
* chore: todos
* chore: store basename 0 in a var for usage
* docs: specify _which_ shell
* chore: move to jane org
* chore: progress
* chore: add todos
* feat: short url
* docs: move some comments to the readme
* chore: comment out unused code
* chore: shellcheck disables (revisit later)
* chore: more validation
* chore: add all the stuff
* Update README.md
* Merge pull request #8 from outime/master
* Fixed bug with spaces in cluster names
* Added MIT license
* Merge pull request #7 from rms1000watt/VTN-13084
* Merge pull request #5 from lanmalkieri/master
* Added link to blog post
* Fixed health check pod selection
* Updated Readme
* Changed time step for example
* Simplified example
* Added Dockerfile for GO application
* Fixed yaml indentation
* Dockerization of canary
* Health check for restarts
* Use labels of service to locate deployment
* Added example
* Package canary script into Dockerfile
* package plugin on its own
* Use kubecontext
* Merge pull request #1 from codefresh-io/fix_scale
* Always scale down production if canary is complete
* Revert "Scale old deployment to zero if canaries are complete"
* Scale old deployment to zero if canaries are complete
* Created readme
* Added sample Codefresh file
* Added dockerfile based on kube-help image
* Added wait period, various cleanups
* Fixed tabs
* Scaling up and down
