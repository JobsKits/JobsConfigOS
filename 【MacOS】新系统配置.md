# `MacOS`新系统配置

[toc]

## 一、温馨提示

* 做不到无人值守，但是可以简化配置流程、平行各端环境

## 二、工作流程

* **C**ommand **L**ine **T**ools（**CLT**）

  ```shell
  xcode-select --install
  sudo xcodebuild -license accept
  ```

* **Xcode**模拟器配件

  ```shell
  rm -rf ~/Library/Caches/com.apple.dt.Xcode
  rm -rf ~/Library/Developer/CoreSimulator/Caches
  
  xcodebuild -downloadPlatform iOS -verbose
  ```

* [**ohMyZsh**](https://ohmyz.sh/)

  ```shell
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ```

* [**Homebrew**](https://brew.sh/)

  > 需要区分芯片安装

  ```shell
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```

  ```shell
  brew update 👉 更新 Homebrew 自己的“软件列表”
  brew upgrade 👉 真正去 升级你已经安装的软件
  
  brew install node
  brew install jenv
  brew install fvm
  brew install pnpm
  brew install ruby
  brew install python
  brew install python3
  brew install fastlane
  brew install Mysql
  brew install hugo
  brew install openjdk  # 最新的Java环境
  brew install openjdk@17
  
  brew install --cask hammerspoon
  brew install --cask flutter
  
  brew cleanup
  ```

* [**npm**](https://www.npmjs.com/)

  ```shell
  sudo npm install -g quicktype
  ```

* [**gem**](https://rubygems.org/)

  ```shell
  sudo gem install cocoapods
  ```

* [**JobsKits**](https://github.com/JobsKits/)

  > 需要进行网络检查，因为在中国大陆，目前是没有办法直接访问[**github.com**](https://github.com/JobsKits/)网站的，需要打开**vpn**，所以这里会有阻塞
  >
  > 如果用户的确没办法绕开网禁，那么这个地方就需要<font color=red>**提示报错**</font>

  * 下载 https://github.com/JobsKits/JobsSoftware.MacOS.git 
  * 下载 https://github.com/JobsKits/JobsMacEnvVarConfig.git 并运行 `install.command`

* 手动下载

  ```url
  https://code.visualstudio.com/
  https://developer.android.com/studio?hl=zh-cn
  https://www.python.org/downloads/
  ```

  