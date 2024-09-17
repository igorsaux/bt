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

#pragma once

#include <array>
#include <bit>
#include <cstdint>
#include <cstring>
#include <iterator>
#include <ranges>
#include <utility>
#include <vector>

namespace bt
{

enum class EResult
{
    Ok,
    DataTooLong
};

template <uint16_t DataSize>
constexpr bool data_fits_v = DataSize + 6 <= UINT16_MAX;

template <uint16_t DataSize>
constexpr uint16_t message_size_v = 10 + DataSize;

template <uint16_t ArraySize>
    requires data_fits_v<ArraySize>
[[nodiscard]] constexpr auto encode_array( const char* data ) noexcept
{
    const uint16_t packet_size = ArraySize + 6;
    std::array<char, 2> packet_size_bytes;

    if constexpr ( std::endian::native == std::endian::little )
    {
        packet_size_bytes = { static_cast<char>( packet_size >> 8 ),
                              static_cast<char>( packet_size ) };
    }
    else
    {
        packet_size_bytes = { static_cast<char>( packet_size ),
                              static_cast<char>( packet_size << 8 ) };
    }

    std::array<char, message_size_v<ArraySize>> result{ '\x00',
                                                        '\x83',
                                                        packet_size_bytes[0],
                                                        packet_size_bytes[1],
                                                        '\x00',
                                                        '\x00',
                                                        '\x00',
                                                        '\x00',
                                                        '\x00' };

    auto* dst = result.data();

    for ( size_t i = 9; i < message_size_v<ArraySize> - 1; i++ )
    {
        dst[i] = data[i - 9];
    }

    return result;
}

template <size_t ArraySize>
[[nodiscard]] constexpr auto
encode_array( const char ( &data )[ArraySize] ) noexcept
{
    return encode_array<ArraySize - 1>( &data[0] );
}

template <typename ArrayType>
[[nodiscard]] constexpr auto encode_array( ArrayType data ) noexcept
{
    return encode_array<std::tuple_size_v<ArrayType>>( data.data() );
}

[[nodiscard]] constexpr std::pair<EResult, std::vector<char>>
encode( const char* data, const size_t length ) noexcept
{
    if ( length + 6 > UINT16_MAX )
    {
        return std::make_pair( EResult::DataTooLong, std::vector<char>{} );
    }

    const auto packet_size = static_cast<uint16_t>( length + 6 );
    const auto* packet_size_bytes =
        reinterpret_cast<const char*>( &packet_size );

    constexpr bool swapBytes = std::endian::native == std::endian::little;

    std::vector result{ '\x00',
                        '\x83',
                        packet_size_bytes[swapBytes ? 1 : 0],
                        packet_size_bytes[swapBytes ? 0 : 1],
                        '\x00',
                        '\x00',
                        '\x00',
                        '\x00',
                        '\x00' };

    const auto old_size = result.size();
    result.resize( result.size() + length + 1 );

    memcpy( result.data() + old_size, data, length );

    return std::make_pair( EResult::Ok, std::move( result ) );
}

template <std::ranges::sized_range ArrayType>
[[nodiscard]] std::pair<EResult, std::vector<char>>
encode( const ArrayType& data ) noexcept
{
    return encode( data.data(), data.size() );
}

[[nodiscard]] inline std::pair<EResult, std::vector<char>>
encode( const char* data ) noexcept
{
    return encode( data, strlen( data ) );
}

} // namespace bt
