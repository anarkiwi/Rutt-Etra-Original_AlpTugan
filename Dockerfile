# syntax=docker/dockerfile:1.7
#
# Rutt-Etra openFrameworks app — multi-stage build.
#
# Stages, ordered from least- to most-frequently invalidated, so editing
# project source only re-runs stage 4 onward:
#
#   1. deps    — apt build dependencies
#   2. of      — download & compile the openFrameworks library
#   3. addons  — clone external addons not bundled with OF 0.12.0
#   4. build   — compile the project
#   5. runtime — slim image containing the binary + bin/data
#
# Build:   DOCKER_BUILDKIT=1 docker build -t rutt-etra .
#
# Run (Linux host with X11):
#     xhost +local:docker
#     docker run --rm -it \
#         -e DISPLAY="$DISPLAY" \
#         -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
#         --device /dev/dri \
#         rutt-etra
#     # when done: xhost -local:docker

ARG UBUNTU_VERSION=22.04
# 0.12.1 has no Linux binary release; 0.12.0 is the latest with a published
# linux64gcc6 tarball. We tried 0.10.1 to match the project's "update for
# of 0.10" commit but its makefile addon parser (config.addons.mk:210)
# trips "missing separator" with newer GNU Make. The addons stage and build
# stage instead patch the deprecated calls (ofCircle, getPixelsRef, ...)
# the old addons rely on so they compile against modern OF.
ARG OF_VERSION=0.12.0
ARG OF_TARBALL=of_v${OF_VERSION}_linux64gcc6_release

# ----------------------------------------------------------------------------
# Stage 1: build dependencies
# ----------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS deps
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-eo", "pipefail", "-c"]

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl wget git make cmake pkg-config python3 \
      build-essential gcc g++ ccache \
      libgl1-mesa-dev libglu1-mesa-dev libglew-dev libglfw3-dev freeglut3-dev \
      libfreetype6-dev libfontconfig1-dev libcairo2-dev \
      libfreeimage-dev libtiff-dev libpng-dev libjpeg-dev \
      libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
      libgstreamer-plugins-bad1.0-dev gstreamer1.0-libav \
      libopenal-dev libasound2-dev libpulse-dev libsndfile1-dev \
      librtaudio-dev librtmidi-dev libudev-dev libusb-1.0-0-dev \
      libgtk-3-dev libxinerama-dev libxcursor-dev libxrandr-dev \
      libxi-dev libxxf86vm-dev libxmu-dev \
      libcurl4-openssl-dev libssl-dev \
      libpoco-dev libuv1-dev liburiparser-dev libpugixml-dev \
      libboost-filesystem-dev libboost-system-dev \
      libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
      libopencv-dev libassimp-dev libbullet-dev libsdl2-dev

# ----------------------------------------------------------------------------
# Stage 2: openFrameworks core library
# ----------------------------------------------------------------------------
FROM deps AS of
ARG OF_VERSION
ARG OF_TARBALL
ENV OF_ROOT=/opt/openFrameworks
ENV PATH=/usr/lib/ccache:${PATH}

RUN --mount=type=cache,target=/tmp/dl,sharing=locked \
    set -eux; \
    cd /tmp/dl; \
    f="${OF_TARBALL}.tar.gz"; \
    if [ ! -s "$f" ] || ! gzip -t "$f" 2>/dev/null; then \
      rm -f "$f" "$f.part"; \
      gh="https://github.com/openframeworks/openFrameworks/releases/download/${OF_VERSION}/${OF_TARBALL}.tar.gz"; \
      cc="https://openframeworks.cc/versions/v${OF_VERSION}/${OF_TARBALL}.tar.gz"; \
      curl -fsSL "$gh" -o "$f.part" || curl -fsSL "$cc" -o "$f.part"; \
      mv "$f.part" "$f"; \
    fi; \
    mkdir -p "${OF_ROOT}"; \
    tar -xzf "$f" -C "${OF_ROOT}" --strip-components=1

# OF's platform make config injects -Werror=return-type globally, which the
# old addons (ofxTimeline, ofxPostGlitch) trip on for code paths that only
# return inside loops/switches. Strip it so warnings don't fail the build.
RUN sed -i 's/-Werror=return-type//g' \
        "${OF_ROOT}/libs/openFrameworksCompiled/project/makefileCommon/config.linux.common.mk"

# Compile the OF library (the long, cacheable step).
RUN --mount=type=cache,target=/root/.ccache \
    cd "${OF_ROOT}/libs/openFrameworksCompiled/project" && \
    make -j"$(nproc)" Release

# ----------------------------------------------------------------------------
# Stage 3: external addons (those not bundled with OF)
#
# Bundled with OF 0.12.0 (no clone needed): ofxGui, ofxXmlSettings, ofxPoco.
# Everything listed in addons.make that isn't bundled is cloned here. Each
# addon is its own RUN line so a single bad URL can be diagnosed without
# busting the cache for the others.
# ----------------------------------------------------------------------------
FROM of AS addons
WORKDIR ${OF_ROOT}/addons
RUN git clone --depth=1 https://github.com/kylemcdonald/ofxFft.git                    ofxFft-Kyle
RUN git clone --depth=1 https://github.com/danomatika/ofxMidi.git                     ofxMidi
RUN git clone --depth=1 https://github.com/alptugan/ofxKorgNanoKontrol.git            ofxKorgNanoKontrol
RUN git clone --depth=1 https://github.com/alptugan/ofxMotionBlurCamera.git           ofxMotionBlurCamera
RUN git clone --depth=1 https://github.com/alptugan/ofxPostProcessing.git             ofxPostProcessing
RUN git clone --depth=1 https://github.com/strimbob/ofxCameraMove.git                 ofxCameraMove
# lpestl fork uses std::function callbacks; the popular hautetechnique fork
# uses Apple block syntax (^) and won't compile on Linux.
RUN git clone --depth=1 https://github.com/lpestl/ofxTweener.git                      ofxTweener
RUN git clone --depth=1 https://github.com/YCAMInterlab/ofxTimecode.git               ofxTimecode
# obviousjim's fork actually exposes ofxMSATimer.h/.cpp; memo's only has MSATimer.h.
RUN git clone --depth=1 https://github.com/obviousjim/ofxMSATimer.git                 ofxMSATimer
RUN git clone --depth=1 https://github.com/Flightphase/ofxTextInputField.git          ofxTextInputField; \
    # The clipboard implementation calls ofAppBaseWindow::getCocoaWindow() —
    # macOS-only. Skip the GLFW clipboard call on Linux; passing nullptr to
    # glfwGet/SetClipboardString queries the most recent context.
    sed -i 's|(GLFWwindow\*) ofGetWindowPtr()->getCocoaWindow()|(GLFWwindow*)nullptr|g' \
        ofxTextInputField/src/ofxTextInputField.cpp
# d3cod3's develop branch carries explicit "fixing OF 0.12 compile" patches
# (Sep 2024). Drop the macOS/Windows-only source files, and strip empty
# `ADDON_INCLUDES = / ADDON_LIBS = / ADDON_SOURCES =` lines from
# addon_config.mk — those empty assignments clobber OF's auto-detected paths
# and break the include resolution for ofxTimeline.h itself.
RUN set -eux; \
    git clone --depth=1 --branch develop https://github.com/d3cod3/ofxTimeline.git ofxTimeline; \
    cd ofxTimeline; \
    rm -f src/ofxRemoveCocoaMenu.mm \
          src/ofxHotKeys_impl_mac.mm \
          src/ofxHotKeys_impl_win.cpp; \
    # ofxTimeline bundles kiss_fft, but ofxFft already provides it. Drop the
    # duplicate to avoid a "multiple definition of kiss_fft_alloc" link error.
    rm -rf libs/kiss; \
    # Strip empty `ADDON_(INCLUDES|LIBS|SOURCES) =` placeholders — they
    # clobber OF's auto-detected paths under the modern addon parser.
    sed -i -E '/^[[:space:]]*ADDON_(INCLUDES|LIBS|SOURCES)[[:space:]]*=[[:space:]]*$/d' addon_config.mk; \
    # Bring deprecated drawing API to OF 0.10+ names (ofDraw*) and fix the
    # ofPixels::getPixelsRef -> getPixels rename.
    find src libs -type f \( -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) -print0 \
      | xargs -0 sed -i \
          -e 's/\bofCircle(/ofDrawCircle(/g' \
          -e 's/\bofLine(/ofDrawLine(/g' \
          -e 's/\bofTriangle(/ofDrawTriangle(/g' \
          -e 's/\bofRect(/ofDrawRectangle(/g' \
          -e 's/getPixelsRef()/getPixels()/g'; \
    # The OpenAL player no longer derives from ofBaseSoundPlayer in modern OF
    # (the interface gained pure-virtual load(filesystem::path) etc. that the
    # addon doesn't implement). Drop the inheritance — nothing in ofxTimeline
    # uses it as an ofBaseSoundPlayer*. The header-include rename handles the
    # sound-types relocation.
    sed -i 's|"ofBaseSoundPlayer\.h"|"ofSoundBaseTypes.h"|' \
        libs/ofOpenALSoundPlayer_TimelineAdditions/src/ofOpenALSoundPlayer_TimelineAdditions.h; \
    sed -i 's|: public ofBaseSoundPlayer, public ofThread|: public ofThread|' \
        libs/ofOpenALSoundPlayer_TimelineAdditions/src/ofOpenALSoundPlayer_TimelineAdditions.h; \
    # ofImage::clone went protected; copy-assignment does the equivalent.
    sed -i 's|thumbnail->clone(\*frame);|*thumbnail = *frame;|' \
        src/ofxTLImageSequenceFrame.cpp; \
    # The 4-arg ofTexture::loadData(ofPixels, w, h, fmt) overload was removed;
    # the 1-arg form infers all of those. Replace the entire (post-getPixels)
    # call site since nested parens defeat a one-shot regex.
    sed -i 's|p.texture->loadData(thumbnail->getPixels(), thumbnail->getWidth(), thumbnail->getHeight(), ofGetGlInternalFormat(thumbnail->getPixels()));|p.texture->loadData(thumbnail->getPixels());|' \
        src/ofxTLImageSequence.cpp; \
    # glm::vec3 has no getInterpolated; glm::mix is the equivalent.
    sed -i 's|camera->getPosition()\.getInterpolated(target->position, dampening)|glm::mix(glm::vec3(camera->getPosition()), glm::vec3(target->position), dampening)|' \
        src/ofxTLCameraTrack.cpp; \
    # ofVec2f * glm::vec3 (ofPoint) and glm::vec3 + ofVec2f are ambiguous; cast
    # the points so the ofVec2f operators kick in. samplePoint, previousSample,
    # nextSample come back as ofPoint/glm::vec3 from the keyframe.
    sed -i \
        -e 's|colorWindow\.getMin() + selectedSample->samplePoint \* ofVec2f|ofVec2f(colorWindow.getMin()) + ofVec2f(selectedSample->samplePoint) * ofVec2f|g' \
        -e 's|colorWindow\.getMin() + previousSample->samplePoint \* ofVec2f|ofVec2f(colorWindow.getMin()) + ofVec2f(previousSample->samplePoint) * ofVec2f|g' \
        -e 's|colorWindow\.getMin() + nextSample->samplePoint \* ofVec2f|ofVec2f(colorWindow.getMin()) + ofVec2f(nextSample->samplePoint) * ofVec2f|g' \
        -e 's|ofDrawLine(c, ofVec2f|ofDrawLine(ofVec2f(c), ofVec2f|' \
        src/ofxTLColorTrack.cpp; \
    # ofPolyline::getVertices() returns std::vector<glm::vec3>& in modern OF;
    # ofPoint (typedef ofVec3f) and glm::vec3 are no longer interchangeable as
    # raw pointers. Take a glm::vec3* instead.
    sed -i 's|ofPoint \* vertex|glm::vec3 * vertex|g' src/ofxTLAudioTrack.cpp; \
    # ofThread::startThread() lost its (blocking, verbose) overload.
    sed -i -E 's|startThread\([^)]*\)|startThread()|g' \
        libs/ofOpenALSoundPlayer_TimelineAdditions/src/ofOpenALSoundPlayer_TimelineAdditions.cpp; \
    : ; \
    # Force -Wno-error=return-type for this addon so the few "control reaches
    # end of non-void" sites don't fail the build.
    printf '\nlinux64:\n\tADDON_CFLAGS = -Wno-error=return-type\n\nlinux:\n\tADDON_CFLAGS = -Wno-error=return-type\n' \
        >> addon_config.mk
RUN git clone --depth=1 https://github.com/Flightphase/ofxRange.git                   ofxRange
RUN git clone --depth=1 https://github.com/Flightphase/ofxTween.git                   ofxTween || \
    git clone --depth=1 https://github.com/arturoc/ofxTween.git                       ofxTween
# ofxAudioDecoder isn't referenced from the project source — kylemcdonald's
# repo also pulls in macOS-only headers (audiodecodercoreaudio.h) and pre-
# built libs. We skip the clone and strip it from addons.make below.
RUN git clone --depth=1 https://github.com/maxillacult/ofxPostGlitch.git              ofxPostGlitch

# ofxPostProcessingManager isn't its own repo — the .h/.cpp live inside
# alptugan/ofxDaseinCosmos along with ofxDC_Utilities.h, which the manager
# header pulls in. Synthesise a minimal addon dir from those three files.
RUN set -eux; \
    mkdir -p ofxPostProcessingManager/src; \
    cd ofxPostProcessingManager/src; \
    base="https://raw.githubusercontent.com/alptugan/ofxDaseinCosmos/master/src"; \
    for f in ofxPostProcessingManager.h ofxPostProcessingManager.cpp ofxDC_Utilities.h; do \
      curl -fsSL "$base/$f" -o "$f"; \
    done

# ----------------------------------------------------------------------------
# Stage 4: project build
# ----------------------------------------------------------------------------
FROM addons AS build
ENV OF_ROOT=/opt/openFrameworks
ENV PATH=/usr/lib/ccache:${PATH}
ARG APP_DIR=${OF_ROOT}/apps/myApps/Rutt-Etra
WORKDIR ${APP_DIR}

# Copy the project sources last so source edits don't bust earlier layers.
COPY . ${APP_DIR}

# TIMELINE_AUDIO_INCLUDED gates ofxTimeline::addAudioTrack/getAudioTrack —
# the project calls both of these and the addon compiles fine with it set.
# Drop ofxAudioDecoder from addons.make — nothing in src/ references it,
# and its kylemcdonald build pulls in macOS-only headers.
RUN --mount=type=cache,target=/root/.ccache \
    set -eux; \
    rm -rf obj bin/Rutt-Etra* ; \
    sed -i '/^ofxAudioDecoder$/d' addons.make; \
    make -j"$(nproc)" Release \
        PROJECT_DEFINES="TIMELINE_AUDIO_INCLUDED"

# ----------------------------------------------------------------------------
# Stage 5: runtime
# ----------------------------------------------------------------------------
FROM ubuntu:${UBUNTU_VERSION} AS runtime
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && apt-get install -y --no-install-recommends \
      libgl1 libglu1-mesa libglew2.2 libglfw3 libfreeimage3 \
      libfreetype6 libfontconfig1 libcairo2 \
      libgstreamer1.0-0 libgstreamer-plugins-base1.0-0 gstreamer1.0-libav \
      libopenal1 libsndfile1 libasound2 libpulse0 \
      librtaudio6 librtmidi6 libudev1 libusb-1.0-0 \
      libgtk-3-0 libxinerama1 libxcursor1 libxrandr2 libxi6 \
      libcurl4 libssl3 \
      libuv1 liburiparser1 libpugixml1v5 \
      libavcodec58 libavformat58 libavutil56 libswscale5 \
      libassimp5 libbullet3.06 \
      libpocofoundation80 libpocoutil80 libpoconet80 libpocoxml80 libpocojson80 libpococrypto80

WORKDIR /app
COPY --from=build /opt/openFrameworks/apps/myApps/Rutt-Etra/bin /app/bin
WORKDIR /app/bin
CMD ["./Rutt-Etra"]
