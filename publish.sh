#!/bin/sh
 
pesde run build && pesde update && pesde publish -y && wally publish && npm publish --access public