# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM --platform=$BUILDPLATFORM python:3.12-alpine AS base

FROM base AS builder

RUN apk update \
    && apk upgrade --no-cache \
    && apk add --no-cache g++ linux-headers \
    && rm -rf /var/cache/apk/*

# get packages
COPY requirements.txt .
RUN pip install -r requirements.txt

FROM base
# Enable unbuffered logging
ENV PYTHONUNBUFFERED=1

RUN apk update \
    && apk upgrade --no-cache \
    && apk add --no-cache libstdc++ \
    && rm -rf /var/cache/apk/*

# get packages
WORKDIR /recommendationservice

# Grab packages from builder
COPY --from=builder /usr/local/lib/python3.12/ /usr/local/lib/python3.12/

# Ensure setuptools/pkg_resources available (not bundled in Python 3.12+)
RUN pip install --no-cache-dir setuptools && \
    python -c "import pkg_resources; print('pkg_resources OK')"

# Add the application
COPY . .

# set listen port
ENV PORT "8080"
EXPOSE 8080

ENTRYPOINT ["python", "recommendation_server.py"]
