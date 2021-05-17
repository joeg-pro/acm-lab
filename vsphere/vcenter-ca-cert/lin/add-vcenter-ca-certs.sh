#!/bin/bash

sudo cp * /etc/pki/ca-trust/source/anchors
sudo update-ca-trust extract

