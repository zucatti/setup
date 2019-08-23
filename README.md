#omneedia-devops

`export KEY=xxxx`

Install volume manager
`curl -L https://raw.githubusercontent.com/Omneedia/setup/master/setup.sh | bash -s -- -t volume`

Install manager
`curl -L https://raw.githubusercontent.com/Omneedia/setup/master/setup.sh | bash -s -- -t manager -v xxx.xxx.xxx.xxx -k VOLUME_TOKEN`

Install worker
`curl -L https://raw.githubusercontent.com/Omneedia/setup/master/setup.sh | bash -s -- -t worker -m xxx.xxx.xxx.xxx`
