<template>
  <el-container style="height: 100vh; overflow: hidden;">
    <!-- 侧边栏 -->
    <el-aside width="220px" style="background: #1a2035; display: flex; flex-direction: column;">
      <div class="logo-area">
        <el-icon size="20"><Message /></el-icon>
        <span>垃圾邮件分类系统</span>
      </div>
      <el-menu
        :default-active="currentPath"
        router
        background-color="#1a2035"
        text-color="#adb5bd"
        active-text-color="#409eff"
        style="border: none; flex: 1;"
      >
        <el-menu-item index="/upload">
          <el-icon><Upload /></el-icon>
          <span>数据上传</span>
        </el-menu-item>
        <el-menu-item index="/preprocess">
          <el-icon><DataAnalysis /></el-icon>
          <span>预处理预览</span>
        </el-menu-item>
        <el-menu-item index="/train">
          <el-icon><TrendCharts /></el-icon>
          <span>模型训练</span>
        </el-menu-item>
        <el-menu-item index="/evaluation">
          <el-icon><DataBoard /></el-icon>
          <span>评估对比</span>
        </el-menu-item>
        <el-menu-item index="/predict">
          <el-icon><Aim /></el-icon>
          <span>预测部署</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <!-- 主区域 -->
    <el-container style="overflow: hidden;">
      <el-header class="top-header">
        <el-breadcrumb separator="/">
          <el-breadcrumb-item>垃圾邮件分类系统</el-breadcrumb-item>
          <el-breadcrumb-item>{{ pageTitles[currentPath] }}</el-breadcrumb-item>
        </el-breadcrumb>
      </el-header>
      <el-main style="background: #f4f5f7; overflow-y: auto; padding: 20px;">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const currentPath = computed(() => route.path)
const pageTitles = {
  '/upload': '数据上传',
  '/preprocess': '预处理预览',
  '/train': '模型训练',
  '/evaluation': '评估对比',
  '/predict': '预测部署',
}
</script>

<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
.logo-area {
  padding: 18px 16px;
  color: #fff;
  font-weight: bold;
  font-size: 14px;
  border-bottom: 1px solid rgba(255,255,255,0.1);
  display: flex;
  align-items: center;
  gap: 10px;
  user-select: none;
}
.top-header {
  background: #fff;
  border-bottom: 1px solid #eee;
  display: flex;
  align-items: center;
  padding: 0 24px;
  height: 56px;
  flex-shrink: 0;
}
.el-menu-item { height: 48px !important; line-height: 48px !important; }
.page-card { background: #fff; border-radius: 8px; padding: 24px; box-shadow: 0 1px 4px rgba(0,0,0,.06); }
</style>
