
SHELL := /bin/bash

# Paths / images
extra_modules_dir := ${PWD}
config := ${PWD}/config
zmk_image := zmkfirmware/zmk-dev-arm:3.5

# Boards
nice := nice_nano_v2

# Keyboard names (quoted for CMake -D)
keyboard_name_nice := -DCONFIG_ZMK_KEYBOARD_NAME="Nice_Corne_View"
keyboard_name_nice_oled := -DCONFIG_ZMK_KEYBOARD_NAME="Nice_Corne_Oled"

# Docker run base options (container name is dynamic per-target)
docker_base := \
	--interactive \
	--tty \
	--workdir /zmk \
	--volume "$(config):/zmk-config:Z" \
	--volume "$(PWD)/zmk:/zmk:Z" \
	--volume "$(extra_modules_dir):/boards:Z" \
	$(zmk_image)

# Common west build invocation (inside container)
west_build_cmd := west build /zmk/app --pristine --board "$(nice)"

# SHIELD definitions (ensure multi-word shields are quoted)
shield_corne_left := -- -DSHIELD="corne_left" -DZMK_CONFIG="/zmk-config"
shield_corne_right := -- -DSHIELD="corne_right" -DZMK_CONFIG="/zmk-config"
shield_corne_left_view := -- -DSHIELD="corne_left nice_view_adapter nice_view" -DZMK_CONFIG="/zmk-config"
shield_corne_right_view := -- -DSHIELD="corne_right nice_view_adapter nice_view" -DZMK_CONFIG="/zmk-config"

# Convenience: mount name for flashing (adjust to your OS/mount points)
nice_mount := /Volumes/NICENANO

# Targets
.PHONY: shell build_left build_right build_left_view build_right_view flash_left flash_right clean

# Open a shell inside the container (interactive)
shell:
	docker run --rm $(docker_base) /bin/bash

# Build targets (use --rm to avoid leftover containers)
build_left:
	docker run --rm --name zmk-build-left $(docker_base) sh -c '\
		$(west_build_cmd) $(shield_corne_left) $(keyboard_name_nice)'

build_right:
	docker run --rm --name zmk-build-right $(docker_base) sh -c '\
		$(west_build_cmd) $(shield_corne_right) $(keyboard_name_nice)'

build_left_view:
	docker run --rm --name zmk-build-left-view $(docker_base) sh -c '\
		$(west_build_cmd) $(shield_corne_left_view) $(keyboard_name_nice_oled)'

build_right_view:
	docker run --rm --name zmk-build-right-view $(docker_base) sh -c '\
		$(west_build_cmd) $(shield_corne_right_view) $(keyboard_name_nice_oled)'

# Flash targets (copy uf2 to mounted bootloader volume)
# Adjust uf2 paths if your build output directory is different.
flash_left:
	@ printf "Waiting for ${nice} bootloader to appear at ${nice_mount}.."
	@ while [ ! -d ${nice_mount} ]; do sleep 1; printf "."; done; printf "\n"
	cp -av build/zephyr/zmk.uf2 ${nice_mount}/nice_corne_left.uf2

flash_right:
	@ printf "Waiting for ${nice} bootloader to appear at ${nice_mount}.."
	@ while [ ! -d ${nice_mount} ]; do sleep 1; printf "."; done; printf "\n"
	cp -av build/zephyr/zmk.uf2 ${nice_mount}/nice_corne_right.uf2

# Clean local repo clone and stop/remove any zmk-* containers
clean:
	if [ -d zmk ]; then rm -rf zmk; fi
	docker ps -aq --filter name='^zmk' | xargs -r docker container rm
	docker volume list -q --filter name='zmk' | xargs -r docker volume rm

