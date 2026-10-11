from fastapi import FastAPI
from pydantic import BaseModel
from ultralytics import YOLOWorld
import base64
from io import BytesIO
from PIL import Image
import uvicorn
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model = YOLOWorld('yolov8s-world.pt')
# Target objects
custom_classes = ["wall", "door", "stairs", "pillar", "person", "car"]
model.set_classes(custom_classes)

class ImagePayload(BaseModel):
    image_base64: str

@app.post("/detect")
async def detect_objects(payload: ImagePayload):
    image_data = base64.b64decode(payload.image_base64)
    image = Image.open(BytesIO(image_data))
    
    # Get image width and height
    img_width, img_height = image.size
    img_area = img_width * img_height

    # Adjust confidence threshold as needed
    results = model.predict(source=image, conf=0.35)
    
    detected_info_list = []
    
    for r in results:
        # Get bounding box coordinates and class info
        for box, c in zip(r.boxes.xyxy, r.boxes.cls):
            class_name_eng = custom_classes[int(c)]
            
            # Box coordinates: [x_min, y_min, x_max, y_max]
            x_min, y_min, x_max, y_max = box.tolist()
            
            # 1. Calculate Position (based on box center X)
            box_center_x = (x_min + x_max) / 2
            if box_center_x < (img_width * 0.33):
                position = "on the right"
            elif box_center_x > (img_width * 0.66):
                position = "on the left"
            else:
                position = "in front"
                
            # 2. Calculate Distance (based on area ratio)
            box_area = (x_max - x_min) * (y_max - y_min)
            area_ratio = box_area / img_area
            
            if area_ratio > 0.4: # Covers >40% of screen = very close
                distance = "very close"
            elif area_ratio > 0.15: # 15-40% = close
                distance = "close"
            else:
                distance = "" # Omit distance if far
                
            # Combine into a natural English phrase (e.g., "very close person on the left")
            if distance:
                description = f"{distance} {class_name_eng} {position}"
            else:
                description = f"{class_name_eng} {position}"
                
            detected_info_list.append(description)
    
    # Remove duplicates
    unique_info = list(set(detected_info_list))
    
    if not unique_info:
        return {"text": "The path is clear."}
    
    # Join multiple objects
    objects_str = ", ".join(unique_info)
    
    # Emphasize text for urgent situations
    if "very close" in objects_str:
        return {"text": f"Warning! {objects_str.capitalize()} detected!"}
    else:
        # Capitalize the first letter for the final sentence
        return {"text": f"{objects_str.capitalize()} detected."}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
