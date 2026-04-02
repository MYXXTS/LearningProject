<template>
  <div>
    <div class="page-card">
      <h2 style="margin-bottom: 20px; font-size: 18px;">评估对比</h2>

      <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 24px;">
        <span style="white-space: nowrap; color: #606266;">选择训练任务：</span>
        <el-select
          v-model="selectedJobId"
          placeholder="请选择训练任务"
          style="width: 320px;"
          @change="loadJobDetail"
        >
          <el-option
            v-for="j in doneJobs"
            :key="j.id"
            :label="`#${j.id}  RF F1=${j.rf_f1}  DT F1=${j.dt_f1}  (${fmtDate(j.created_at)})`"
            :value="j.id"
          />
        </el-select>
        <el-button size="small" @click="refreshJobs"><el-icon><Refresh /></el-icon></el-button>
      </div>

      <div v-if="job">
        <!-- Metrics comparison table -->
        <el-row :gutter="24" style="margin-bottom: 24px;">
          <el-col :span="12">
            <el-card>
              <template #header>
                <span style="font-weight: bold; color: #409eff;">🌲 随机森林（集成模型）</span>
              </template>
              <el-descriptions :column="2" border size="small">
                <el-descriptions-item label="准确率">
                  <span class="metric-val">{{ (job.rf_accuracy * 100).toFixed(2) }}%</span>
                </el-descriptions-item>
                <el-descriptions-item label="精确率">
                  <span class="metric-val">{{ (job.rf_precision * 100).toFixed(2) }}%</span>
                </el-descriptions-item>
                <el-descriptions-item label="召回率">
                  <span class="metric-val">{{ (job.rf_recall * 100).toFixed(2) }}%</span>
                </el-descriptions-item>
                <el-descriptions-item label="F1 分数">
                  <span class="metric-val primary">{{ (job.rf_f1 * 100).toFixed(2) }}%</span>
                </el-descriptions-item>
              </el-descriptions>
            </el-card>
          </el-col>
          <el-col :span="12">
            <el-card>
              <template #header>
                <span style="font-weight: bold; color: #e6a23c;">🌱 决策树（单模型基线）</span>
              </template>
              <el-descriptions :column="2" border size="small">
                <el-descriptions-item label="准确率">
                  <span class="metric-val">{{ (job.dt_accuracy * 100).toFixed(2) }}%</span>
                </el-descriptions-item>
                <el-descriptions-item label="精确率">
                  <span class="metric-val">{{ (job.dt_precision * 100).toFixed(2) }}%</span>
                </el-descriptions-item>
                <el-descriptions-item label="召回率">
                  <span class="metric-val">{{ (job.dt_recall * 100).toFixed(2) }}%</span>
                </el-descriptions-item>
                <el-descriptions-item label="F1 分数">
                  <span class="metric-val warning">{{ (job.dt_f1 * 100).toFixed(2) }}%</span>
                </el-descriptions-item>
              </el-descriptions>
            </el-card>
          </el-col>
        </el-row>

        <!-- Bar Chart -->
        <el-card style="margin-bottom: 24px;">
          <template #header><span>指标对比图</span></template>
          <v-chart :option="chartOption" style="height: 300px;" autoresize />
        </el-card>

        <!-- Classification Reports -->
        <el-row :gutter="24">
          <el-col :span="12">
            <el-card>
              <template #header><span style="color: #409eff;">随机森林 Classification Report</span></template>
              <pre class="report-pre">{{ job.rf_report }}</pre>
            </el-card>
          </el-col>
          <el-col :span="12">
            <el-card>
              <template #header><span style="color: #e6a23c;">决策树 Classification Report</span></template>
              <pre class="report-pre">{{ job.dt_report }}</pre>
            </el-card>
          </el-col>
        </el-row>
      </div>

      <el-empty v-if="!job && !loading" description="请选择已完成的训练任务" style="margin-top: 30px;" />
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { ElMessage } from 'element-plus'
import { listJobs, getJob } from '../api/index.js'

const allJobs = ref([])
const doneJobs = computed(() => allJobs.value.filter(j => j.status === 'done'))
const selectedJobId = ref(null)
const job = ref(null)
const loading = ref(false)

const refreshJobs = async () => {
  try {
    allJobs.value = await listJobs()
    if (doneJobs.value.length > 0 && !selectedJobId.value) {
      selectedJobId.value = doneJobs.value[0].id
      await loadJobDetail()
    }
  } catch (e) {
    ElMessage.error(e.message)
  }
}

const loadJobDetail = async () => {
  if (!selectedJobId.value) return
  loading.value = true
  try {
    job.value = await getJob(selectedJobId.value)
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    loading.value = false
  }
}

const chartOption = computed(() => {
  if (!job.value) return {}
  const metrics = ['准确率', '精确率', '召回率', 'F1']
  const rf = [job.value.rf_accuracy, job.value.rf_precision, job.value.rf_recall, job.value.rf_f1]
  const dt = [job.value.dt_accuracy, job.value.dt_precision, job.value.dt_recall, job.value.dt_f1]
  return {
    tooltip: { trigger: 'axis', formatter: (params) => {
      return params.map(p => `${p.seriesName}: ${(p.value * 100).toFixed(2)}%`).join('<br/>')
    }},
    legend: { data: ['随机森林', '决策树'] },
    xAxis: { type: 'category', data: metrics },
    yAxis: { type: 'value', min: 0, max: 1, axisLabel: { formatter: (v) => `${(v*100).toFixed(0)}%` } },
    series: [
      { name: '随机森林', type: 'bar', data: rf, itemStyle: { color: '#409eff' }, label: { show: true, formatter: (p) => `${(p.value*100).toFixed(1)}%`, position: 'top' } },
      { name: '决策树', type: 'bar', data: dt, itemStyle: { color: '#e6a23c' }, label: { show: true, formatter: (p) => `${(p.value*100).toFixed(1)}%`, position: 'top' } },
    ],
  }
})

const fmtDate = (dt) => dt ? new Date(dt).toLocaleString('zh-CN') : '-'

onMounted(refreshJobs)
</script>

<style scoped>
.metric-val { font-size: 16px; font-weight: bold; }
.metric-val.primary { color: #409eff; }
.metric-val.warning { color: #e6a23c; }
.report-pre {
  font-family: 'Courier New', monospace;
  font-size: 12px;
  background: #f4f4f5;
  padding: 12px;
  border-radius: 4px;
  overflow-x: auto;
  line-height: 1.6;
  white-space: pre;
}
</style>
