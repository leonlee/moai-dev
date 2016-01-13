// Copyright (c) 2010-2011 Zipline Games, Inc. All Rights Reserved.
// http://getmoai.com

#ifndef	MOAIPLATFORMERBODY2D_H
#define	MOAIPLATFORMERBODY2D_H

#include <moai-sim/MOAIProp.h>

class MOAISurfaceBuffer2D;
class MOAIPartition;
class MOAIGrid;

//================================================================//
// MOAIPlatformerBody2D
//================================================================//
// TODO: doxygen
class MOAIPlatformerBody2D :
	public virtual MOAIProp {
private:
	
	friend class MOAIPlatformerFsm2D;
	
	float		mFloorAngle;
	float		mFloorCos;
	
	float		mCeilAngle;
	float		mCeilCos;
	
	ZLVec2D		mMove;
	float		mHRad;
	float		mVRad;
	
	float		mSkirt;
	
	u32			mSteps;
	bool		mCompleted;
	
	u32			mDetachMode;
	
	bool		mIsStanding;
	
	ZLBox		mDebugBounds; // used for debug drawing only
	
	//----------------------------------------------------------------//
	static int			_getStatus					( lua_State* L );
	static int			_setCeilingAngle			( lua_State* L );
	static int			_setEllipse					( lua_State* L );
	static int			_setFloorAngle				( lua_State* L );
	static int			_setMove					( lua_State* L );
	
	//----------------------------------------------------------------//
	u32					AffirmInterfaceMask			( MOAIPartition& partition );
	void				GatherSurfacesForBounds		( MOAISurfaceSampler2D& buffer, const ZLBox& bounds );
	void				GetTouching					( ZLVec2D& loc, MOAISurfaceSampler2D& sampler );
	ZLRect				GetUnitRectForWorldBounds	( const ZLBox& bounds );
	ZLAffine3D			GetUnitToWorldMtx			();
	ZLAffine3D			GetWorldToUnitMtx			();
	void				SetCeilingAngle				( float angle );
	void				SetFloorAngle				( float angle );

public:
	
	enum {
		DETACH_MODE_NONE,
		DETACH_ON_UP,
		DETACH_ON_ANY,
	};
	
	DECL_LUA_FACTORY ( MOAIPlatformerBody2D )
	
	IS ( Standing, mIsStanding, true )
	
	//----------------------------------------------------------------//
	void			Draw					( int subPrimID );
	u32				GetPropBounds			( ZLBox& bounds );
					MOAIPlatformerBody2D	();
					~MOAIPlatformerBody2D	();
	void			OnDepNodeUpdate			();
	void			RegisterLuaClass		( MOAILuaState& state );
	void			RegisterLuaFuncs		( MOAILuaState& state );
	void			SetMove					( float x, float y );
};

#endif