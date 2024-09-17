//-----------------------------------------------------------------------------
// Copyright 2024 Igor Spichkin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------------------

#include "socket_buffer.hpp"
#include <cstring>

namespace btcmd
{

CSocketBuffer::CSocketBuffer( std::unique_ptr<ISocket>&& socket )
    : mSocket( std::move( socket ) )
{
}

bool CSocketBuffer::Read( char* dst, size_t length ) noexcept
{
    if ( mCursor == mBuffer.size() || mCursor + length > mBuffer.size() )
    {
        const auto bufferSize = std::max( length, static_cast<size_t>( 256 ) );
        const auto oldSize = mBuffer.size();

        mBuffer.resize( oldSize + bufferSize, 0 );

        const auto bytesRecv = mSocket->Recv( mBuffer.data() + oldSize,
                                              static_cast<int>( bufferSize ) );

        mBuffer.resize( oldSize + bytesRecv );

        // TODO: timeout
        if ( mCursor == mBuffer.size() || mCursor + length >= mBuffer.size() )
        {
            return false;
        }
    }

    memcpy( dst, mBuffer.data() + mCursor, length );
    mCursor += static_cast<ptrdiff_t>( length );

    return true;
}

} // namespace btcmd
