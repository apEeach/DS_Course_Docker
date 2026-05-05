**这是一个本地编译环境的docker，可以在虚拟机中运行这个local_docker来复制项目的环境**

<u>注意本地代码是使用了mysql的docker，实际环境中是用的数据库服务器，注意代码的统一</u>



### 使用方式

1、在当前目录下面创建文件夹  ./mysql_data（这里有时候需要设置一下权限）

2、拉取app的代码，这里需要命名为code，否则docker compose后，app代码映射不到，可参照docker-compose.yml

```
git clone git@github.com:apEeach/DS_Course.git ./code
```

3、更新子仓库

```
cd ./code
git submodule update --init --recursive
```

4、准备完成直接进行docker构建，见Docker指令的1

**注意：2，3两步需要在4之前执行，否则会挂载不到目录**



### Docker指令

#### 1、docker构建

```
docker compose up -d --build
```



#### 2、停止容器

```
docker compose down
```



#### 3、重新启动服务

```
docker compose up -d
```



#### 4、重启docker服务 -- 遇到docker环境有问题，就停止容器，重启服务

```
sudo systemctl daemon-reload
sudo systemctl restart docker
```



#### 5、配置 /etc/docker/daemon.json 内容 — 网络docker pull很慢的时候，可以配置这个内容

（1）bip 跟 default-address-pools，是当出现docker的桥接网络与实际网卡网段有冲突的时候设置的

（2）registry-mirrors 是一些镜像地址

```
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1panel.live",
    "https://docker.xuanyuan.me",
    "https://docker.1ms.run",
    "https://hub.rat.dev",
    "https://mirror.aliyuncs.com",
    "https://registry.docker-cn.com"
  ],
  "dns": ["8.8.8.8", "114.114.114.114"],
  "bip": "10.200.0.1/16",
  "default-address-pools": [
    {
      "base": "10.201.0.0/16",
      "size": 24
    }
  ]
}
EOF
```



#### 6、docker compose安装很慢，或者安装不下来

（1）docker安装，用于启动docker

```
sudo apt update
```

（2） 安装必要的依赖项

```
sudo apt install ca-certificates curl gnupg lsb-release
```

（3）移除之前的仓库配置 -- 如果有的话

```
sudo rm -f /etc/apt/sources.list.d/docker.list
```

（4） 添加Docker官方GPG密钥

```
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

（5）正确添加仓库（使用正确的架构标识）

```
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

（6）更新包列表

```
sudo apt update
```

（7）尝试安装

```
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

