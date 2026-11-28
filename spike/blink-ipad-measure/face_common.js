// Worker 版と画面側版で共通の「結果を小さくまとめる」処理。
// 返すのはスコアと顔の位置・大きさだけ（映像や全ランドマークは返さない）。
export const VERSIONS = {
  tasksVision: "1.2.3",
  model: "face_landmarker/float16/1",
  modelSha256: "64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff",
};

export function landmarkerOptions(modelUrl, delegate, canvas) {
  const opts = {
    baseOptions: { modelAssetPath: modelUrl, delegate },
    runningMode: "VIDEO",
    numFaces: 1,
    outputFaceBlendshapes: true,
    outputFacialTransformationMatrixes: false,
  };
  if (canvas) opts.canvas = canvas;
  return opts;
}

export function summarize(r) {
  const faces = r?.faceLandmarks?.length || 0;
  let left = null;
  let right = null;
  const cats = r?.faceBlendshapes?.[0]?.categories;
  if (cats) {
    for (const c of cats) {
      if (c.categoryName === "eyeBlinkLeft") left = c.score;
      else if (c.categoryName === "eyeBlinkRight") right = c.score;
    }
  }
  let box = null;
  if (faces) {
    let minX = 1, minY = 1, maxX = 0, maxY = 0;
    for (const p of r.faceLandmarks[0]) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    box = { cx: (minX + maxX) / 2, cy: (minY + maxY) / 2, size: Math.max(maxX - minX, maxY - minY) };
  }
  return { faces, left, right, box };
}

export function resourceEntries(sinceMs = 0) {
  try {
    return performance
      .getEntriesByType("resource")
      .filter((e) => e.startTime >= sinceMs && /vendor/.test(e.name))
      .map((e) => ({
        file: e.name.split("/").pop(),
        durationMs: Math.round(e.duration),
        transferBytes: e.transferSize ?? null,
        bodyBytes: e.decodedBodySize ?? null,
        fromCache: e.transferSize === 0 && e.decodedBodySize > 0,
      }));
  } catch {
    return [];
  }
}
