<template>
  <div>
    <!-- Model Selector -->
    <div class="page-card" style="margin-bottom: 20px;">
      <h2 style="margin-bottom: 20px; font-size: 18px;">预测部署</h2>
      <div style="display: flex; align-items: center; gap: 12px;">
        <span style="white-space: nowrap; color: #606266;">选择模型：</span>
        <el-select v-model="selectedJobId" placeholder="请选择已完成的训练任务" style="width: 360px;">
          <el-option
            v-for="j in doneJobs"
            :key="j.id"
            :label="`#${j.id}  RF F1=${j.rf_f1}  [${fmtDate(j.created_at)}]`"
            :value="j.id"
          />
        </el-select>
        <el-button size="small" @click="loadJobs"><el-icon><Refresh /></el-icon></el-button>
      </div>
    </div>

    <!-- Prediction Tabs -->
    <div class="page-card" style="margin-bottom: 20px;">
      <el-tabs v-model="activeTab">
        <!-- Single Prediction -->
        <el-tab-pane label="单条预测" name="single">
          <div style="max-width: 700px; margin-top: 12px;">
            <el-input
              v-model="singleMsg"
              type="textarea"
              :rows="4"
              placeholder="请输入邮件/短信内容，例如：You have won a FREE prize…"
              resize="vertical"
            />
            <el-button
              type="primary"
              style="margin-top: 12px;"
              :loading="singleLoading"
              :disabled="!selectedJobId || !singleMsg.trim()"
              @click="doSinglePredict"
            >
              <el-icon><Aim /></el-icon> 开始预测
            </el-button>

            <!-- Result Card -->
            <div v-if="singleResult" class="result-card" :class="singleResult.prediction">
              <div class="result-badge">{{ singleResult.prediction === 'spam' ? '🚨 SPAM' : '✅ HAM' }}</div>
              <div class="result-confidence">
                置信度：<b>{{ (singleResult.confidence * 100).toFixed(1) }}%</b>
              </div>
              <el-progress
                :percentage="+(singleResult.confidence * 100).toFixed(1)"
                :color="singleResult.prediction === 'spam' ? '#f56c6c' : '#67c23a'"
                style="margin-top: 10px;"
              />
              <div style="margin-top: 12px; color: #606266; font-size: 13px;">{{ singleResult.message }}</div>
            </div>
          </div>
        </el-tab-pane>

        <!-- Batch Prediction -->
        <el-tab-pane label="批量预测" name="batch">
          <div style="max-width: 600px; margin-top: 12px;">
            <el-alert
              title="上传 CSV 文件，系统将自动识别消息列并完成批量预测，结果以 CSV 格式下载。"
              type="info"
              show-icon
              :closable="false"
              style="margin-bottom: 16px;"
            />
            <el-upload
              :auto-upload="false"
              accept=".csv"
              :on-change="handleBatchFile"
              :show-file-list="true"
              :limit="1"
            >
              <el-button type="primary" plain><el-icon><Upload /></el-icon> 选择 CSV 文件</el-button>
            </el-upload>
            <el-button
              type="success"
              style="margin-top: 16px;"
              :loading="batchLoading"
              :disabled="!selectedJobId || !batchFile"
              @click="doBatchPredict"
            >
              <el-icon><Download /></el-icon> 批量预测并下载结果
            </el-button>
            <div v-if="batchDone" style="margin-top: 12px; color: #67c23a;">
              ✅ 批量预测完成，文件已下载。
            </div>
          </div>
        </el-tab-pane>
      </el-tabs>
    </div>

    <!-- Prediction History -->
    <div class="page-card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <h3 style="font-size: 16px;">预测历史（最近 50 条）</h3>
        <el-button size="small" @click="loadHistory"><el-icon><Refresh /></el-icon> 刷新</el-button>
      </div>
      <el-table :data="history" stripe size="small" style="width: 100%;" max-height="360">
        <el-table-column prop="id" label="ID" width="60" align="center" />
        <el-table-column prop="job_id" label="模型ID" width="70" align="center" />
        <el-table-column prop="message" label="消息摘要" min-width="240" show-overflow-tooltip />
        <el-table-column label="预测结果" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="row.prediction === 'spam' ? 'danger' : 'success'" size="small">
              {{ row.prediction }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="置信度" width="90" align="center">
          <template #default="{ row }">{{ (row.confidence * 100).toFixed(1) }}%</template>
        </el-table-column>
        <el-table-column label="时间" width="160">
          <template #default="{ row }">{{ fmtDate(row.created_at) }}</template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { listJobs, predictSingle, predictBatch, getPredictionHistory } from '../api/index.js'

const allJobs = ref([])
const doneJobs = computed(() => allJobs.value.filter(j => j.status === 'done'))
const selectedJobId = ref(null)
const activeTab = ref('single')

const singleMsg = ref('')
const singleResult = ref(null)
const singleLoading = ref(false)

const batchFile = ref(null)
const batchLoading = ref(false)
const batchDone = ref(false)

const history = ref([])

const loadJobs = async () => {
  try {
    allJobs.value = await listJobs()
    if (doneJobs.value.length > 0 && !selectedJobId.value) {
      selectedJobId.value = doneJobs.value[0].id
    }
  } catch (e) {
    ElMessage.error(e.message)
  }
}

const doSinglePredict = async () => {
  singleLoading.value = true
  singleResult.value = null
  try {
    singleResult.value = await predictSingle({ job_id: selectedJobId.value, message: singleMsg.value })
    await loadHistory()
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    singleLoading.value = false
  }
}

const handleBatchFile = (file) => {
  batchFile.value = file.raw
  batchDone.value = false
}

const doBatchPredict = async () => {
  if (!batchFile.value) return
  batchLoading.value = true
  batchDone.value = false
  try {
    const response = await predictBatch(selectedJobId.value, batchFile.value)
    const url = URL.createObjectURL(new Blob([response.data], { type: 'text/csv' }))
    const a = document.createElement('a')
    a.href = url
    a.download = 'predictions.csv'
    a.click()
    URL.revokeObjectURL(url)
    batchDone.value = true
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    batchLoading.value = false
  }
}

const loadHistory = async () => {
  try {
    history.value = await getPredictionHistory()
  } catch (e) {
    // silent
  }
}

const fmtDate = (dt) => dt ? new Date(dt).toLocaleString('zh-CN') : '-'

onMounted(async () => {
  await loadJobs()
  await loadHistory()
})
</script>

<style scoped>
.result-card {
  margin-top: 20px;
  padding: 20px;
  border-radius: 8px;
  border: 2px solid #eee;
}
.result-card.spam {
  background: #fff0f0;
  border-color: #f56c6c;
}
.result-card.ham {
  background: #f0fff4;
  border-color: #67c23a;
}
.result-badge {
  font-size: 24px;
  font-weight: bold;
  margin-bottom: 8px;
}
.result-card.spam .result-badge { color: #f56c6c; }
.result-card.ham .result-badge { color: #67c23a; }
.result-confidence { font-size: 14px; color: #303133; }
</style>
