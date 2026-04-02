import { createRouter, createWebHistory } from 'vue-router'
import DataUpload from '../views/DataUpload.vue'
import Preprocessing from '../views/Preprocessing.vue'
import TrainModel from '../views/TrainModel.vue'
import Evaluation from '../views/Evaluation.vue'
import Prediction from '../views/Prediction.vue'

const routes = [
  { path: '/', redirect: '/upload' },
  { path: '/upload', component: DataUpload },
  { path: '/preprocess', component: Preprocessing },
  { path: '/train', component: TrainModel },
  { path: '/evaluation', component: Evaluation },
  { path: '/predict', component: Prediction },
]

export default createRouter({
  history: createWebHistory(),
  routes,
})
