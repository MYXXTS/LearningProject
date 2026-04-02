<template>
  <div>
    <div class="page-card">
      <h2 style="margin-bottom: 20px; font-size: 18px;">数据上传</h2>

      <!-- Upload Area -->
      <el-upload
        class="upload-area"
        drag
        :auto-upload="false"
        accept=".csv"
        :on-change="handleFileChange"
        :show-file-list="false"
      >
        <el-icon size="48" color="#c0c4cc"><UploadFilled /></el-icon>
        <div style="margin-top: 12px; font-size: 15px; color: #606266;">将 CSV 文件拖到此处，或<em style="color: #409eff;">点击上传</em></div>
        <div style="margin-top: 6px; font-size: 12px; color: #909399;">支持包含 ham/spam 标签列和消息列的 CSV 文件</div>
      </el-upload>

      <div v-if="selectedFile" style="margin-top: 16px; display: flex; align-items: center; gap: 12px;">
        <el-tag type="info">{{ selectedFile.name }}</el-tag>
        <el-button type="primary" :loading="uploading" @click="doUpload">
          <el-icon><Upload /></el-icon> 上传
        </el-button>
      </div>

      <el-alert v-if="errorMsg" :title="errorMsg" type="error" show-icon style="margin-top: 16px;" />
    </div>

    <!-- Dataset List -->
    <div class="page-card" style="margin-top: 20px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px;">
        <h3 style="font-size: 16px;">已上传数据集</h3>
        <el-button size="small" @click="loadDatasets"><el-icon><Refresh /></el-icon> 刷新</el-button>
      </div>
      <el-table :data="datasets" v-loading="loadingList" stripe style="width: 100%;">
        <el-table-column prop="id" label="ID" width="60" />
        <el-table-column prop="name" label="文件名" min-width="200" show-overflow-tooltip />
        <el-table-column prop="total_rows" label="总行数" width="90" align="center" />
        <el-table-column label="Spam" width="80" align="center">
          <template #default="{ row }">
            <el-tag type="danger" size="small">{{ row.spam_count }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="Ham" width="80" align="center">
          <template #default="{ row }">
            <el-tag type="success" size="small">{{ row.ham_count }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="上传时间" width="170">
          <template #default="{ row }">{{ fmtDate(row.created_at) }}</template>
        </el-table-column>
        <el-table-column label="操作" width="140" align="center">
          <template #default="{ row }">
            <el-button size="small" type="primary" link @click="goPreprocess(row.id)">
              分析
            </el-button>
            <el-button size="small" type="success" link @click="goTrain(row.id)">
              训练
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { uploadDataset, listDatasets } from '../api/index.js'

const router = useRouter()
const datasets = ref([])
const selectedFile = ref(null)
const uploading = ref(false)
const loadingList = ref(false)
const errorMsg = ref('')

const handleFileChange = (file) => {
  selectedFile.value = file.raw
}

const doUpload = async () => {
  if (!selectedFile.value) return
  uploading.value = true
  errorMsg.value = ''
  try {
    await uploadDataset(selectedFile.value)
    ElMessage.success('上传成功')
    selectedFile.value = null
    await loadDatasets()
  } catch (e) {
    errorMsg.value = e.message
  } finally {
    uploading.value = false
  }
}

const loadDatasets = async () => {
  loadingList.value = true
  try {
    datasets.value = await listDatasets()
  } catch (e) {
    ElMessage.error(e.message)
  } finally {
    loadingList.value = false
  }
}

const goPreprocess = (id) => router.push({ path: '/preprocess', query: { id } })
const goTrain = (id) => router.push({ path: '/train', query: { id } })

const fmtDate = (dt) => dt ? new Date(dt).toLocaleString('zh-CN') : '-'

onMounted(loadDatasets)
</script>

<style scoped>
.upload-area { width: 100%; }
:deep(.el-upload-dragger) {
  width: 100%; height: 160px; display: flex; flex-direction: column;
  align-items: center; justify-content: center;
}
</style>
