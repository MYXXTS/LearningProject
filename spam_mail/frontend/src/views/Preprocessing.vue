<template>
  <div>
    <div class="page-card">
      <h2 style="margin-bottom: 20px; font-size: 18px;">预处理预览 & 探索性分析</h2>

      <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 24px;">
        <span style="white-space: nowrap; color: #606266;">选择数据集：</span>
        <el-select
          v-model="selectedId"
          placeholder="请选择数据集"
          style="width: 280px;"
          @change="fetchEDA"
        >
          <el-option
            v-for="ds in datasets"
            :key="ds.id"
            :label="`#${ds.id} ${ds.name} (${ds.total_rows} 行)`"
            :value="ds.id"
          />
        </el-select>
        <el-button v-if="selectedId" type="primary" :loading="loading" @click="fetchEDA">
          <el-icon><DataAnalysis /></el-icon> 分析
        </el-button>
      </div>

      <!-- Stats Cards -->
      <div v-if="eda" class="stats-row">
        <el-card class="stat-card">
          <div class="stat-num">{{ eda.total }}</div>
          <div class="stat-label">有效行数</div>
        </el-card>
        <el-card class="stat-card danger">
          <div class="stat-num">{{ eda.spam_count }}</div>
          <div class="stat-label">Spam 数量</div>
        </el-card>
        <el-card class="stat-card success">
          <div class="stat-num">{{ eda.ham_count }}</div>
          <div class="stat-label">Ham 数量</div>
        </el-card>
        <el-card class="stat-card info">
          <div class="stat-num">{{ eda.avg_msg_len }}</div>
          <div class="stat-label">平均文本长度</div>
        </el-card>
      </div>

      <!-- Charts -->
      <div v-if="eda" class="charts-row">
        <div class="chart-box">
          <h4 style="margin-bottom: 12px; color: #303133;">标签分布</h4>
          <img :src="`data:image/png;base64,${eda.label_dist_chart}`" style="max-width: 100%;" />
        </div>
        <div class="chart-box">
          <h4 style="margin-bottom: 12px; color: #303133;">文本长度分布</h4>
          <img :src="`data:image/png;base64,${eda.len_dist_chart}`" style="max-width: 100%;" />
        </div>
      </div>
    </div>

    <!-- Data Preview -->
    <div v-if="eda" class="page-card" style="margin-top: 20px;">
      <h3 style="margin-bottom: 16px; font-size: 16px;">数据预览（前 20 条）</h3>
      <el-table :data="eda.preview" stripe size="small" style="width: 100%;">
        <el-table-column prop="label" label="标签" width="80" align="center">
          <template #default="{ row }">
            <el-tag :type="row.label === 'spam' ? 'danger' : 'success'" size="small">
              {{ row.label }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="message" label="消息内容" show-overflow-tooltip />
      </el-table>
    </div>

    <el-empty v-if="!eda && !loading" description="请先选择数据集" style="margin-top: 40px;" />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { listDatasets, getDatasetEDA } from '../api/index.js'

const route = useRoute()
const datasets = ref([])
const selectedId = ref(null)
const eda = ref(null)
const loading = ref(false)

const fetchEDA = async () => {
  if (!selectedId.value) return
  loading.value = true
  eda.value = null
  try {
    eda.value = await getDatasetEDA(selectedId.value)
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  try {
    datasets.value = await listDatasets()
    if (route.query.id) {
      selectedId.value = parseInt(route.query.id)
      await fetchEDA()
    }
  } catch (e) {
    ElMessage.error(e.message)
  }
})
</script>

<style scoped>
.stats-row {
  display: flex;
  gap: 16px;
  flex-wrap: wrap;
  margin-bottom: 24px;
}
.stat-card {
  flex: 1;
  min-width: 120px;
  text-align: center;
  border-left: 4px solid #409eff;
}
.stat-card.danger { border-left-color: #f56c6c; }
.stat-card.success { border-left-color: #67c23a; }
.stat-card.info { border-left-color: #909399; }
.stat-num { font-size: 28px; font-weight: bold; color: #303133; }
.stat-label { font-size: 13px; color: #909399; margin-top: 4px; }
.charts-row {
  display: flex;
  gap: 24px;
  flex-wrap: wrap;
  margin-bottom: 8px;
}
.chart-box {
  flex: 1;
  min-width: 300px;
  background: #f9f9f9;
  border-radius: 6px;
  padding: 16px;
}
</style>
