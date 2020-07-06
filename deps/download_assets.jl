using Pkg.Artifacts
using ghr_jll
using Pkg.BinaryPlatforms

# See this issue: https://github.com/JuliaGizmos/WebIO.jl/issues/422
username = "arthursoprana"
version_tag = "v0.2.5"
reponame = "Knockout.jl"

function build_js_bundle(dir)
	deps = Dict(
	    "knockout.js" => "https://knockoutjs.com/downloads/knockout-3.4.2.js",
	    "knockout_punches.js" => "https://mbest.github.io/knockout.punches/knockout.punches.min.js",
	)

    for (dep_name, dep_url) in deps
		download(
            dep_url,
            joinpath(dir, dep_name),
        )
    end
end

hash = create_artifact() do dir
    # Build all JS files in `dir`
	build_js_bundle(dir)
end

# Now that the artifact is built on our machine and we know its content hash,
# let's package it up into a tarball and host it on GitHub releases:
function archive_and_upload()
	local tarball_hash
	mktempdir() do dir
		tarball_hash = archive_artifact(hash, joinpath(dir, "jsbundle.tar.gz"))
		# Use `ghr` from `ghr_jll` to upload this file to the GitHub releases of WebIO.jl
		# Note that I think you will need to export `GITHUB_TOKEN=<token>` before running this.
		# Alternatively, you can skip this step and manually upload the tarball using the browser.
		ghr() do ghr
			run(`$(ghr) -recreate -u $(username) -r $(reponame) $(version_tag) $(dir)`)
		end
	end
	return tarball_hash
end
tarball_hash = archive_and_upload()

# Finally, let's bind this out to our Artifact file.
# This relative pathing is assuming that this script lives within `deps/`.
artifacts_toml = joinpath(dirname(@__DIR__), "Artifacts.toml")
url = "https://github.com/$(username)/$(reponame)/releases/download/$(version_tag)/jsbundle.tar.gz"

function bind_artifact_for(platform)
	bind_artifact!(
		# Where the TOML file is that we're writing this binding into
		artifacts_toml,
		# The name of the artifact, used by the `@artifact_str()` macro later
		"jsbundle",
		# The content-hash of the artifact
		hash;
		platform=platform,
		# Information about how to download this artifact
		download_info = [
			(url, tarball_hash),
		],
	)
end

for _arch in [:i686, :x86_64]
	bind_artifact_for(Windows(_arch))
end

for _arch in [:i686, :x86_64, :aarch64]
	bind_artifact_for(Linux(_arch))
end

bind_artifact_for(MacOS())
