<template>
  <div>
    <div class="page-card">
      <h2 style="margin-bottom: 20px; font-size: 18px;">模型训练</h2>

      <el-form :model="form" label-width="140px" style="max-width: 520px;">
        <el-form-item label="选择数据集">
          <el-select v-model="form.dataset_id" placeholder="请选择数据集" style="width: 100%;">
            <el-option
              v-for="ds in datasets"
              :key="ds.id"
              :label="`#${ds.id} ${ds.name} (${ds.total_rows} 行)`"
              :value="ds.id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="随机森林树数量">
          <el-input-number v-model="form.n_estimators" :min="10" :max="500" :step="10" style="width: 160px;" />
        </el-form-item>
        <el-form-item label="欠采样平衡类别">
          <el-switch v-model="form.balance" active-text="开启" inactive-text="关闭" />
          <span style="font-size: 12px; color: #909399; margin-left: 12px;">开启后将下采样多数类（ham）使类别均衡</span>
        </el-form-item>
        <el-form-item>
          <el-button
            type="primary"
            :loading="training"
            :disabled="!form.dataset_id"
            @click="doTrain"
          >
            <el-icon><TrendCharts /></el-icon>
            {{ training ? '训练中（约需 30-60 秒）…' : '开始训练' }}
          </el-button>
        </el-form-item>
      </el-form>

      <el-alert
        v-if="trainResult"
        type="success"
        show-icon
        :closable="false"
        style="margin-top: 8px; max-width: 520px;"
      >
        <template #title>
          训练完成！随机森林 F1 = <b>{{ trainResult.rf_f1 }}</b>，决策树 F1 = <b>{{ trainResult.dt_f1 }}</b>
        </template>
        <template #default>
          <el-button size="small" type="primary" link @click="$router.push('/evaluation')">查看详细评估 →</el-button>
        </template>
      </el-alert>

      <el-alert v-if="errorMsg" :title="errorMsg" type="error" show-icon style="margin-top: 8px; max-width: 520px;" />
    </div>

    <!-- Training Jobs List -->
    <div class="page-card" style="margin-top: 20px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <h3 style="font-size: 16px;">训练记录</h3>
        <el-button size="small" @click="loadJobs"><el-icon><Refresh /></el-icon> 刷新</el-button>
      </div>
      <el-table :data="jobs" v-loading="loadingJobs" stripe size="small" style="width: 100%;">
        <el-table-column prop="id" label="ID" width="60" align="center" />
        <el-table-column prop="dataset_id" label="数据集ID" width="80" align="center" />
        <el-table-column label="状态" width="90" align="center">
          <template #default="{ row }">
            <el-tag
              :type="{ done: 'success', running: 'warning', failed: 'danger', pending: 'info' }[row.status]"
              size="small"
            >{{ row.status }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="RF F1" width="80" align="center">
          <template #default="{ row }">{{ row.rf_f1 ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="DT F1" width="80" align="center">
          <template #default="{ row }">{{ row.dt_f1 ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="树数量" width="80" align="center">
          <template #default="{ row }">{{ row.n_estimators ?? '-' }}</template>
        </el-table-column>
        <el-table-column label="创建时间" width="160">
          <template #default="{ row }">{{ fmtDate(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="120" align="center">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="$router.push('/evaluation')">评估</el-button>
            <el-button v-if="row.status === 'done'" size="small" type="success" link @click="$router.push('/predict')">预测</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { ElMessage } from 'element-plus'
import { listDatasets, startTraining, listJobs } from '../api/index.js'

const route = useRoute()
const datasets = ref([])
const jobs = ref([])
const form = ref({ dataset_id: null, n_estimators: 100, balance: true })
const training = ref(false)
const loadingJobs = ref(false)
const trainResult = ref(null)
const errorMsg = ref('')

const doTrain = async () => {
  if (!form.value.dataset_id) return
  training.value = true
  trainResult.value = null
  errorMsg.value = ''
  try {
    const result = await startTraining(form.value)
    trainResult.value = result
    ElMessage.success('训练成功！')
    await loadJobs()
  } catch (e) {
    errorMsg.value = e.message
  } finally {
    training.value = false
  }
}

const loadJobs = async () => {
  loadingJobs.value = true
  try {
    jobs.value = await listJobs()
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    loadingJobs.value = false
  }
}

const fmtDate = (dt) => dt ? new Date(dt).toLocaleString('zh-CN') : '-'

onMounted(async () => {
  try {
    datasets.value = await listDatasets()
    if (route.query.id) form.value.dataset_id = parseInt(route.query.id)
  } catch (e) {
    ElMessage.error(e.message)
  }
  await loadJobs()
})
</script>
