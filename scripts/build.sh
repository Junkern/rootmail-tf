#!/bin/bash
./node_modules/.bin/esbuild --outfile=index.js --bundle --platform=node ./src/lambda.js
zip lambda_function_payload.zip index.js