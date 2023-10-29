#include "CameraSceneNode.h"
#include "../Lua/LuaEnvironment.h"
#include "PrimeEngine/Events/StandardEvents.h"

#include "DebugRenderer.h"
#define Z_ONLY_CAM_BIAS 0.0f


namespace PE {
	namespace Components {

		PE_IMPLEMENT_CLASS1(CameraSceneNode, SceneNode);

		CameraSceneNode::CameraSceneNode(PE::GameContext &context, PE::MemoryArena arena, Handle hMyself) : SceneNode(context, arena, hMyself)
		{
			m_near = 0.05f;
			m_far = 2000.0f;
		}
		void CameraSceneNode::addDefaultComponents()
		{
			Component::addDefaultComponents();
			PE_REGISTER_EVENT_HANDLER(Events::Event_CALCULATE_TRANSFORMATIONS, CameraSceneNode::do_CALCULATE_TRANSFORMATIONS);
		}

		void CameraSceneNode::do_CALCULATE_TRANSFORMATIONS(Events::Event *pEvt)
		{
			Handle hParentSN = getFirstParentByType<SceneNode>();
			if (hParentSN.isValid())
			{
				Matrix4x4 parentTransform = hParentSN.getObject<PE::Components::SceneNode>()->m_worldTransform;
				m_worldTransform = parentTransform * m_base;
			}

			Matrix4x4 &mref_worldTransform = m_worldTransform;

			Vector3 pos = Vector3(mref_worldTransform.m[0][3], mref_worldTransform.m[1][3], mref_worldTransform.m[2][3]);
			Vector3 n = Vector3(mref_worldTransform.m[0][2], mref_worldTransform.m[1][2], mref_worldTransform.m[2][2]);
			Vector3 target = pos + n;
			Vector3 up = Vector3(mref_worldTransform.m[0][1], mref_worldTransform.m[1][1], mref_worldTransform.m[2][1]);

			m_worldToViewTransform = CameraOps::CreateViewMatrix(pos, target, up);

			m_worldTransform2 = mref_worldTransform;

			m_worldTransform2.moveForward(Z_ONLY_CAM_BIAS);

			Vector3 pos2 = Vector3(m_worldTransform2.m[0][3], m_worldTransform2.m[1][3], m_worldTransform2.m[2][3]);
			Vector3 n2 = Vector3(m_worldTransform2.m[0][2], m_worldTransform2.m[1][2], m_worldTransform2.m[2][2]);
			Vector3 target2 = pos2 + n2;
			Vector3 up2 = Vector3(m_worldTransform2.m[0][1], m_worldTransform2.m[1][1], m_worldTransform2.m[2][1]);

			m_worldToViewTransform2 = CameraOps::CreateViewMatrix(pos2, target2, up2);

			PrimitiveTypes::Float32 aspect = (PrimitiveTypes::Float32)(m_pContext->getGPUScreen()->getWidth()) / (PrimitiveTypes::Float32)(m_pContext->getGPUScreen()->getHeight());

			PrimitiveTypes::Float32 verticalFov = 0.33f * PrimitiveTypes::Constants::c_Pi_F32;
			if (aspect < 1.0f)
			{
				//ios portrait view
				static PrimitiveTypes::Float32 factor = 0.5f;
				verticalFov *= factor;
			}

			m_viewToProjectedTransform = CameraOps::CreateProjectionMatrix(verticalFov,
				aspect,
				m_near, m_far);

			PrimitiveTypes::Float32 debugFov = 0.6f * PrimitiveTypes::Constants::c_Pi_F32; // for making the culling easier to see
			PrimitiveTypes::Float32 debugm_far = 100.0f;
			PrimitiveTypes::Float32 debugm_near = 0.50f;
			Matrix4x4 m_debugViewToProjectedTransform = CameraOps::CreateProjectionMatrix(debugFov, aspect, debugm_near, debugm_far);

			// Reference: https://www.gamedevs.org/uploads/fast-extraction-viewing-frustum-planes-from-world-view-projection-matrix.pdf
			Matrix4x4 m_wvp = m_debugViewToProjectedTransform * m_worldToViewTransform;
			SceneNode::do_CALCULATE_TRANSFORMATIONS(pEvt);

			m_cameraFrustum.m_planes[0] = Vector4( // left
				(m_wvp.m[3][0] + m_wvp.m[0][0]), //A
				(m_wvp.m[3][1] + m_wvp.m[0][1]), //B
				(m_wvp.m[3][2] + m_wvp.m[0][2]), //C
				(m_wvp.m[3][3] + m_wvp.m[0][3])  //D
			);

			m_cameraFrustum.m_planes[1] = Vector4(
				(m_wvp.m[3][0] - m_wvp.m[0][0]), //A
				(m_wvp.m[3][1] - m_wvp.m[0][1]), //B
				(m_wvp.m[3][2] - m_wvp.m[0][2]), //C
				(m_wvp.m[3][3] - m_wvp.m[0][3])  //D
			);

			m_cameraFrustum.m_planes[2] = Vector4(
				(m_wvp.m[3][0] + m_wvp.m[1][0]), //A
				(m_wvp.m[3][1] + m_wvp.m[1][1]), //B
				(m_wvp.m[3][2] + m_wvp.m[1][2]), //C
				(m_wvp.m[3][3] + m_wvp.m[1][3])  //D
			);

			m_cameraFrustum.m_planes[3] = Vector4(
				(m_wvp.m[3][0] - m_wvp.m[1][0]), //A
				(m_wvp.m[3][1] - m_wvp.m[1][1]), //B
				(m_wvp.m[3][2] - m_wvp.m[1][2]), //C
				(m_wvp.m[3][3] - m_wvp.m[1][3])  //D
			);

			m_cameraFrustum.m_planes[4] = Vector4(
				(m_wvp.m[3][0] + m_wvp.m[2][0]), //A
				(m_wvp.m[3][1] + m_wvp.m[2][1]), //B
				(m_wvp.m[3][2] + m_wvp.m[2][2]), //C
				(m_wvp.m[3][3] + m_wvp.m[2][3])  //D
			);

			m_cameraFrustum.m_planes[5] = Vector4(
				(m_wvp.m[3][0] - m_wvp.m[2][0]), //A
				(m_wvp.m[3][1] - m_wvp.m[2][1]), //B
				(m_wvp.m[3][2] - m_wvp.m[2][2]), //C
				(m_wvp.m[3][3] - m_wvp.m[2][3])  //D
			);
		}

		// for any mesh instance, perform this check to see if the bounding box is within the view frustum. Use min and max to construct the vertices of AABB and test them against the frustum planes.
		bool CameraSceneNode::viewFrustumMesh_intersection_check(Vector3 min, Vector3 max)
		{
			Vector3 boundingBoxVerts[8];
			boundingBoxVerts[0] = Vector3(min.m_x, min.m_y, min.m_z);
			boundingBoxVerts[1] = Vector3(max.m_x, min.m_y, min.m_z);
			boundingBoxVerts[2] = Vector3(min.m_x, max.m_y, min.m_z);
			boundingBoxVerts[3] = Vector3(min.m_x, min.m_y, max.m_z);
			boundingBoxVerts[4] = Vector3(min.m_x, max.m_y, max.m_z);
			boundingBoxVerts[5] = Vector3(max.m_x, min.m_y, max.m_z);
			boundingBoxVerts[6] = Vector3(max.m_x, max.m_y, min.m_z);
			boundingBoxVerts[7] = Vector3(max.m_x, max.m_y, max.m_z);

			int vertCount = 6;
			Vector3 planeNormal[6];
			for (int i = 0; i < 6; i++) {
				planeNormal[i] = Vector3(m_cameraFrustum.m_planes[i].m_x, m_cameraFrustum.m_planes[i].m_y, m_cameraFrustum.m_planes[i].m_z);
			}


			//    // I HAVE NO IDEA WHY THIS DOESNT WORK ON THE RIGHT PLANE BUT IM TOO TIRED TO DEBUG
			//for (int vert = 0; vert < 8; vert++) { // for each vertex
			//	Vector3 currentV = boundingBoxVerts[vert];
			//	// see if it is in frustum by checking 6 planes 
			//	// Ax + By + Cz + D >= 0 means this point is inside the half space 
			//	for (int plane = 0; plane < 6; plane++) {
			//		// if current vertex is outside of ANY positive half space then discard it and go to the next vertex
			//		if (planeNormal[plane].dotProduct(currentV) + m_cameraFrustum.m_planes[plane].m_w < 0)
			//			vertCount--;
			//			break;
			//	}
			//	
			//}

			//if (vertCount > 0) // if ANY vertex is in the view frustum then we need to render it
			//	return true;
			//else
			//	return false;

			//TRY DEBUGGING MY PREVIOUS APPROACH
			for (int vert = 0; vert < 8; vert++) { // for each vertex
				Vector3 currentV = boundingBoxVerts[vert];

				if (
					(m_cameraFrustum.m_planes[0].m_x * currentV.m_x + m_cameraFrustum.m_planes[0].m_y * currentV.m_y + m_cameraFrustum.m_planes[0].m_z * currentV.m_z + m_cameraFrustum.m_planes[0].m_w >= 0) &&
					(m_cameraFrustum.m_planes[1].m_x * currentV.m_x + m_cameraFrustum.m_planes[1].m_y * currentV.m_y + m_cameraFrustum.m_planes[1].m_z * currentV.m_z + m_cameraFrustum.m_planes[1].m_w >= 0) &&
					(m_cameraFrustum.m_planes[2].m_x * currentV.m_x + m_cameraFrustum.m_planes[2].m_y * currentV.m_y + m_cameraFrustum.m_planes[2].m_z * currentV.m_z + m_cameraFrustum.m_planes[2].m_w >= 0) &&
					(m_cameraFrustum.m_planes[3].m_x * currentV.m_x + m_cameraFrustum.m_planes[3].m_y * currentV.m_y + m_cameraFrustum.m_planes[3].m_z * currentV.m_z + m_cameraFrustum.m_planes[3].m_w >= 0) &&
					(m_cameraFrustum.m_planes[4].m_x * currentV.m_x + m_cameraFrustum.m_planes[4].m_y * currentV.m_y + m_cameraFrustum.m_planes[4].m_z * currentV.m_z + m_cameraFrustum.m_planes[4].m_w >= 0) &&
					(m_cameraFrustum.m_planes[5].m_x * currentV.m_x + m_cameraFrustum.m_planes[5].m_y * currentV.m_y + m_cameraFrustum.m_planes[5].m_z * currentV.m_z + m_cameraFrustum.m_planes[5].m_w >= 0)
					)
				{
					return true;

				}
				return false;
			}
		} //bool CameraSceneNode::viewFrustumMesh_intersection_check()

	}; // namespace Components

}; // namespace PE
